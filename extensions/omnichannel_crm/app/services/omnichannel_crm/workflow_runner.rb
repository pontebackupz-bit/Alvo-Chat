# Runs a native chatbot flow inside a conversation.
#
# A run walks the flow's blocks until it has to wait: for the customer's reply
# (`ask_question`, `menu`) or for a delay (`wait`). WorkflowRunJob resumes it.
# Connections are `{ source, sourceHandle, target }`; a missing `sourceHandle`
# means the block's single `next` output. A block without a connection for the
# chosen output ends the run.
class OmnichannelCrm::WorkflowRunner
  NODE_TYPES = %w[start send_message ask_question menu condition add_label transfer_team assign_agent wait end].freeze
  MAX_STEPS = 50
  MAX_WAIT_MINUTES = 7 * 24 * 60
  VARIABLE_PATTERN = /\{\{\s*([\w.]+)\s*\}\}/

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

  def initialize(run)
    @run = run
  end

  def perform(reply: nil)
    run.with_lock do
      next unless resumable?(reply)

      resume(reply) unless run.running?
      execute if run.running?
      run.save!
    end
  rescue StandardError => e
    Rails.logger.error("Workflow run #{run.id} failed: #{e.message}")
    run.update!(status: :failed, error_message: e.message.truncate(500))
  end

  private

  attr_reader :run

  delegate :conversation, :workflow, to: :run

  # A reply only resumes a run waiting for one, and only when it arrived after
  # the question; other wake-ups (delays, the first start) skip waiting runs.
  def resumable?(reply)
    return false unless run.active?
    return run.waiting_reply? && reply.created_at >= run.waiting_since if reply

    !run.waiting_reply?
  end

  def resume(reply)
    return move_to(next_node_id(current_node, 'next')) if run.waiting_delay?

    text = reply.content.to_s.strip
    run.variables = run.variables.merge('resposta' => text)
    handle = reply_handle(current_node, text)
    return send_message(menu_text(current_node['data'])) if handle.nil?

    move_to(next_node_id(current_node, handle))
  end

  def execute
    MAX_STEPS.times do
      outcome = execute_node(current_node)
      case outcome
      when :wait_reply then return run.assign_attributes(status: :waiting_reply, waiting_since: Time.current)
      when :wait_delay then return run.assign_attributes(status: :waiting_delay, waiting_since: Time.current)
      when :finish then return run.assign_attributes(status: :completed)
      when :stop then return
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

  def execute_start(_data)
    human_already_replied? ? cancel : 'next'
  end

  def execute_send_message(data)
    send_message(data['content'])
    'next'
  end

  def execute_ask_question(data)
    send_message(data['content'])
    :wait_reply
  end

  def execute_menu(data)
    send_message(menu_text(data))
    :wait_reply
  end

  def execute_condition(data)
    condition_met?(data) ? 'true' : 'false'
  end

  def execute_add_label(data)
    conversation.add_labels(Array(data['labels']))
    'next'
  end

  def execute_transfer_team(data)
    conversation.update!(team: conversation.account.teams.find(data['team_id']))
    'next'
  end

  def execute_assign_agent(data)
    conversation.update!(assignee: conversation.account.users.find(data['agent_id']))
    'next'
  end

  def execute_wait(data)
    schedule_resume(data)
    :wait_delay
  end

  def execute_end(data)
    conversation.update!(status: :resolved) if ActiveModel::Type::Boolean.new.cast(data['resolve'])
    :finish
  end

  # Conversations opened by an agent, or by a message sent from the phone, are
  # already handled by a person.
  def human_already_replied?
    conversation.messages.outgoing.where(sender_type: 'User')
                .or(conversation.messages.outgoing.where("content_attributes ->> 'external_echo' = 'true'"))
                .exists?
  end

  def cancel
    run.assign_attributes(status: :cancelled)
    :stop
  end

  def reply_handle(node, text)
    case node['type']
    when 'ask_question'
      variable = node.dig('data', 'variable').presence
      run.variables = run.variables.merge(variable => text) if variable
      'next'
    when 'menu' then menu_handle(node, text)
    end
  end

  # Matches the option number ("2") or its text. Unknown answers follow the
  # "other" output when it is connected, otherwise the menu is sent again.
  def menu_handle(node, text)
    options = Array(node.dig('data', 'options'))
    index = Integer(text, exception: false)
    option = (options[index - 1] if index&.between?(1, options.size)) ||
             options.find { |candidate| candidate['label'].to_s.strip.casecmp?(text) }
    return "option:#{option['id']}" if option

    next_node_id(node, 'other') ? 'other' : nil
  end

  def menu_text(data)
    options = Array(data['options']).each_with_index.map { |option, index| "#{index + 1}. #{option['label']}" }
    [data['content'].presence, options.join("\n")].compact.join("\n\n")
  end

  def condition_met?(data)
    value = lookup(data['variable'].presence || 'resposta').to_s.strip
    expected = data['value'].to_s.strip
    case data['operator']
    when 'equals' then value.casecmp?(expected)
    when 'not_empty' then value.present?
    when 'empty' then value.blank?
    else value.downcase.include?(expected.downcase)
    end
  end

  def schedule_resume(data)
    minutes = data['minutes'].to_i.clamp(1, MAX_WAIT_MINUTES)
    OmnichannelCrm::WorkflowRunJob.set(wait: minutes.minutes).perform_later(run.id)
  end

  def send_message(content)
    text = interpolate(content.to_s).strip
    return true if text.blank?

    conversation.messages.create!(account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :outgoing,
                                  content: text, content_attributes: { 'crm_workflow_run_id' => run.id })
  end

  def interpolate(text)
    text.gsub(VARIABLE_PATTERN) { lookup(Regexp.last_match(1)).to_s }
  end

  def lookup(key)
    contact = conversation.contact
    case key
    when 'contato.nome' then contact.name
    when 'contato.telefone' then contact.phone_number
    when 'contato.email' then contact.email
    else run.variables[key]
    end
  end

  def current_node
    workflow.nodes.find { |node| node['id'] == run.current_node_id } || raise("Bloco #{run.current_node_id} não existe mais no fluxo.")
  end

  def next_node_id(node, handle)
    workflow.connections.find { |connection| connection['source'] == node['id'] && (connection['sourceHandle'].presence || 'next') == handle }
            &.fetch('target')
  end

  def move_to(node_id)
    return run.assign_attributes(status: :completed) if node_id.nil?

    run.assign_attributes(current_node_id: node_id, status: :running, waiting_since: nil)
  end
end
