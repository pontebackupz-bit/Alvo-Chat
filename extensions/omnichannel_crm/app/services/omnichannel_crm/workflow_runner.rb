# Runs a chatbot flow inside a conversation.
#
# A run walks the flow's blocks until it has to wait: for the customer's reply
# (`ask_question`, `menu`), for a delay (`wait`) or for a human attendance to
# end (`transfer_team` with `wait_for_agent`). WorkflowRunJob resumes it.
# Connections are `{ source, sourceHandle, target }`; a missing `sourceHandle`
# means the block's single `next` output. A block without a connection for the
# chosen output ends the path: the run returns to the flow that called it as a
# subflow, or completes.
#
# State lives in `run.variables`: `flow` (flow variables), `input` (what the
# previous block produced), answers saved by questions and `__`-prefixed
# bookkeeping (subflow call stack, inactivity timer, retries).
class OmnichannelCrm::WorkflowRunner
  include OmnichannelCrm::FlowNodes::Messaging
  include OmnichannelCrm::FlowNodes::Logic
  include OmnichannelCrm::FlowNodes::Attendance

  NODE_TYPES = %w[start send_message ask_question menu condition branch set_variables split wait inactivity add_label
                  transfer_team assign_agent subflow code integration end].freeze
  # Blocks kept for reference only; nothing connects to them.
  PASSIVE_TYPES = %w[note].freeze
  MAX_STEPS = 100
  MAX_WAIT_MINUTES = 7 * 24 * 60

  def self.start_for(conversation)
    workflow = OmnichannelCrm::Workflow.active.where(account_id: conversation.account_id).order(:id)
                                       .find { |candidate| candidate.starts_on_new_conversation?(conversation.inbox_id) }
    return unless workflow

    # The savepoint keeps an enclosing transaction usable when the unique index
    # rejects a second run for the same conversation.
    run = OmnichannelCrm::WorkflowRun.transaction(requires_new: true) do
      OmnichannelCrm::WorkflowRun.create!(account_id: conversation.account_id, workflow: workflow, conversation: conversation,
                                          status: :running, current_node_id: workflow.start_node.fetch('id'))
    end
    OmnichannelCrm::WorkflowRunJob.perform_later(run.id)
  rescue ActiveRecord::RecordNotUnique
    # The conversation is already running a flow.
    nil
  end

  # Chatwoot label titles allow letters, digits, `-` and `_` only.
  def self.label_title(name)
    name.to_s.strip.downcase.gsub(/[^\p{L}\p{N}_-]+/, '_').gsub(/\A_+|_+\z/, '').presence
  end

  def initialize(run)
    @run = run
  end

  # `reply` answers a question or menu, `inactivity_token` fires an
  # inactivity timer and `attendance` continues after a human attendance.
  def perform(reply: nil, inactivity_token: nil, attendance: false)
    run.with_lock do
      next unless resumable?(reply, inactivity_token, attendance)

      wake_up(reply, inactivity_token, attendance)
      execute if run.running?
      run.save!
    end
  rescue StandardError => e
    Rails.logger.error("Workflow run #{run.id} failed: #{e.message}")
    run.update!(status: :failed, error_message: e.message.truncate(500))
  end

  private

  attr_reader :run

  delegate :conversation, to: :run
  delegate :contact, to: :conversation

  # A reply only resumes a run waiting for one, and only when it arrived after
  # the question; other wake-ups must match what the run waits for.
  def resumable?(reply, inactivity_token, attendance)
    return false unless run.active?
    return run.waiting_reply? && reply.created_at >= run.waiting_since if reply
    return run.waiting_reply? && inactivity_token == waiting_token if inactivity_token
    return run.waiting_agent? if attendance

    !run.waiting_reply? && !run.waiting_agent?
  end

  def wake_up(reply, inactivity_token, attendance)
    if inactivity_token then fire_inactivity
    elsif attendance then resume_after_attendance
    elsif reply then resume_with_reply(reply)
    elsif run.waiting_delay? then move_to(next_node_id(current_node, 'next'))
    end
  end

  def resume_with_reply(reply)
    text = reply.content.to_s.strip
    remember('resposta' => text)
    handle = reply_handle(current_node, text)
    return enter_waiting_reply if handle == :retry
    return send_message(menu_text(current_node['data'])).then { enter_waiting_reply } if handle.nil?

    move_to(next_node_id(current_node, handle))
  end

  def execute
    MAX_STEPS.times do
      outcome = execute_node(current_node)
      case outcome
      when :wait_reply then return enter_waiting_reply
      when :wait_delay then return run.assign_attributes(status: :waiting_delay, waiting_since: Time.current)
      when :wait_agent then return run.assign_attributes(status: :waiting_agent, waiting_since: Time.current)
      when :finish then finish_path
      when :jumped, :stop then nil
      else move_to(next_node_id(current_node, outcome))
      end
      return unless run.running?
    end
    raise "O fluxo passou de #{MAX_STEPS} blocos sem aguardar o cliente. Verifique se há um ciclo."
  end

  def execute_node(node)
    raise "Bloco sem suporte para execução: #{node['type']}" unless NODE_TYPES.include?(node['type'])

    send("execute_#{node['type']}", node['data'] || {})
  end

  # Conversations opened by an agent, or by a message sent from the phone, are
  # already handled by a person. Subflows start without this check.
  def execute_start(_data)
    return 'next' if run.variables['__workflow_id'].present?

    human_already_replied? ? cancel : 'next'
  end

  def human_already_replied?
    conversation.messages.outgoing.where(sender_type: 'User')
                .or(conversation.messages.outgoing.where("content_attributes ->> 'external_echo' = 'true'"))
                .exists?
  end

  def cancel
    run.assign_attributes(status: :cancelled)
    :stop
  end

  def enter_waiting_reply
    run.assign_attributes(status: :waiting_reply, waiting_since: Time.current)
    timer = run.variables['__inactivity']
    return unless timer.is_a?(Hash)

    OmnichannelCrm::WorkflowRunJob.set(wait: timer['minutes'].to_i.minutes).perform_later(run.id, nil, waiting_token)
  end

  def waiting_token
    run.waiting_since&.to_i&.to_s
  end

  def fire_inactivity
    timer = run.variables['__inactivity']
    remember('__inactivity' => nil, '__workflow_id' => subflow_id(timer['workflow_id']), '__stack' => [])
    move_to(next_node_id(node_by_id(timer['node_id']), 'inactivity'))
  end

  def template
    OmnichannelCrm::FlowTemplate.new { |root| template_root(root) }
  end

  def template_root(root)
    case root
    when 'flow' then flow_variables
    when 'user' then contact_profile
    when 'input' then run.variables['input']
    when 'contato' then { 'nome' => contact.name, 'telefone' => contact.phone_number, 'email' => contact.email }
    when 'env' then nil
    else run.variables[root]
    end
  end

  def contact_profile
    first_name = contact.name.to_s.split.first
    (contact.custom_attributes || {}).stringify_keys.merge(
      'id' => contact.id, 'name' => contact.name, 'PrimeiroNome' => first_name, 'firstName' => first_name,
      'phone' => contact.phone_number, 'email' => contact.email
    )
  end

  def remember(values)
    run.variables = run.variables.merge(values)
  end

  def current_workflow
    workflow_id = run.variables['__workflow_id']
    return run.workflow if workflow_id.blank? || workflow_id == run.workflow_id

    @workflows ||= {}
    @workflows[workflow_id] ||= OmnichannelCrm::Workflow.where(account_id: run.account_id).find(workflow_id)
  end

  # nil while running the run's own flow.
  def subflow_id(workflow_id)
    workflow_id == run.workflow_id ? nil : workflow_id
  end

  def current_node
    node_by_id(run.current_node_id)
  end

  def node_by_id(node_id)
    current_workflow.nodes.find { |node| node['id'] == node_id } || raise("Bloco #{node_id} não existe mais no fluxo.")
  end

  def next_node_id(node, handle)
    current_workflow.connections.find do |connection|
      connection['source'] == node['id'] && (connection['sourceHandle'].presence || 'next') == handle
    end&.fetch('target')
  end

  def move_to(node_id)
    return finish_path if node_id.nil?

    run.assign_attributes(current_node_id: node_id, status: :running, waiting_since: nil)
  end

  # The end of a path returns to the calling flow when there is one.
  def finish_path
    frame = call_stack.last
    return run.assign_attributes(status: :completed) unless frame

    remember('__stack' => call_stack[0...-1], '__workflow_id' => subflow_id(frame['workflow_id']))
    move_to(next_node_id(node_by_id(frame['node_id']), 'success'))
  end
end
