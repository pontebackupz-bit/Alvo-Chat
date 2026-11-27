# Blocks that only change the flow's state or path.
module OmnichannelCrm::FlowNodes::Logic
  # EZ.Chat "Run code" blocks cannot run here; the ones that only keep the
  # digits of the answer are recognised and done natively.
  DIGITS_ONLY_CODE = %r{\.match\(\s*/\\d\+/g\s*\)\s*\.join\(\s*(''|"")\s*\)}
  COMPARISONS = {
    'gt' => :>, 'gte' => :>=, 'lt' => :<, 'lte' => :<=
  }.freeze

  private

  # Legacy single condition: `true` / `false` outputs.
  def execute_condition(data)
    value = template.evaluate(data['variable'].presence || 'resposta').to_s.strip
    expected = data['value'].to_s.strip
    met = case data['operator']
          when 'equals' then value.casecmp?(expected)
          when 'not_empty' then value.present?
          when 'empty' then value.blank?
          else value.downcase.include?(expected.downcase)
          end
    met ? 'true' : 'false'
  end

  # Several rules; the first that matches names the output, else `else`.
  def execute_branch(data)
    rule = Array(data['rules']).find { |candidate| rule_met?(candidate) }
    rule ? rule['id'].to_s : 'else'
  end

  def rule_met?(rule)
    left = template.value(rule['left'].to_s)
    right = template.value(rule['right'].to_s)
    operator = rule['operator'].to_s
    return compare_numbers(left, right, COMPARISONS[operator]) if COMPARISONS.key?(operator)

    rule_text_match?(operator, left, right)
  end

  def rule_text_match?(operator, left, right)
    case operator
    when 'eq' then same_value?(left, right)
    when 'neq' then !same_value?(left, right)
    when 'contains' then normalize_words(left).include?(normalize_words(right))
    when 'notContains' then normalize_words(left).exclude?(normalize_words(right))
    when 'startsWith' then normalize_words(left).start_with?(normalize_words(right))
    when 'exists' then OmnichannelCrm::FlowTemplate.truthy?(left)
    when 'empty' then !OmnichannelCrm::FlowTemplate.truthy?(left)
    else false
    end
  end

  def same_value?(left, right)
    numbers = [left, right].map { |value| OmnichannelCrm::FlowTemplate.number(value) }
    return numbers.first == numbers.last if numbers.all? && [left, right].none? { |value| value.nil? || value == '' }

    normalize_words(left) == normalize_words(right)
  end

  def compare_numbers(left, right, operator)
    numbers = [left, right].map { |value| OmnichannelCrm::FlowTemplate.number(value) }
    numbers.all? && numbers.first.public_send(operator, numbers.last)
  end

  # Values are templates; each one sees the values set before it.
  def execute_set_variables(data)
    values = data['values'].is_a?(Hash) ? data['values'] : {}
    if data['scope'] == 'contact'
      attributes = values.transform_values { |value| template.value(value) }
      contact.update!(custom_attributes: (contact.custom_attributes || {}).merge(attributes))
    else
      values.each { |key, value| remember('flow' => flow_variables.merge(key.to_s => template.value(value))) }
    end
    'next'
  end

  def flow_variables
    run.variables['flow'].is_a?(Hash) ? run.variables['flow'] : {}
  end

  def execute_split(data)
    splits = Array(data['splits']).select { |split| split['value'].to_f.positive? }
    return 'else' if splits.empty?

    point = rand * splits.sum { |split| split['value'].to_f }
    splits.find { |split| (point -= split['value'].to_f).negative? }&.fetch('id').to_s || splits.last['id'].to_s
  end

  # From now on, a customer silent for `minutes` while the flow waits for
  # an answer follows this block's `inactivity` output.
  def execute_inactivity(data)
    minutes = data['minutes'].to_i.clamp(1, OmnichannelCrm::WorkflowRunner::MAX_WAIT_MINUTES)
    remember('__inactivity' => { 'node_id' => current_node['id'], 'workflow_id' => current_workflow.id, 'minutes' => minutes })
    'next'
  end

  def execute_code(data)
    text = input_text
    return 'error' unless data['code'].to_s.match?(DIGITS_ONLY_CODE) && text.match?(/\d/)

    remember('input' => text.gsub(/\D/, ''))
    'success'
  end

  def input_text
    input = run.variables['input']
    (input.is_a?(Hash) ? input['text'] : input).to_s
  end

  # External systems (Oracle, Google Sheets) are not connected: the flow
  # carries on through the block's error output.
  def execute_integration(data)
    Rails.logger.info("Workflow run #{run.id}: integration #{data['provider']} is not configured, following the error output")
    remember('input' => nil)
    'error'
  end

  def execute_wait(data)
    minutes = data['minutes'].to_i.clamp(1, OmnichannelCrm::WorkflowRunner::MAX_WAIT_MINUTES)
    OmnichannelCrm::WorkflowRunJob.set(wait: minutes.minutes).perform_later(run.id)
    :wait_delay
  end

  def execute_add_label(data)
    titles = Array(data['labels']).filter_map { |label| self.class.label_title(label) }.uniq
    titles.each { |title| ensure_label(title) }
    conversation.add_labels(titles)
    'next'
  end

  def ensure_label(title)
    conversation.account.labels.find_or_create_by!(title: title)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    nil
  end

  def execute_end(data)
    conversation.update!(status: :resolved) if ActiveModel::Type::Boolean.new.cast(data['resolve'])
    :finish
  end

  # Runs another flow of the account (looked up by name). When `returns` is
  # set, its end comes back here through `success`; otherwise the run ends
  # with it. A missing flow follows `error`, else `success`, else ends.
  def execute_subflow(data)
    target = find_subflow(data['flow_name'])
    return missing_subflow_handle unless target

    payload = subflow_payload(data['data'])
    remember('input' => payload, 'flow' => flow_variables.merge(payload))
    stack = ActiveModel::Type::Boolean.new.cast(data['returns']) ? call_stack + [frame_here] : []
    remember('__stack' => stack, '__workflow_id' => target.id)
    move_to(target.start_node&.fetch('id'))
    :jumped
  end

  def find_subflow(name)
    wanted = comparable_name(name)
    return if wanted.blank?

    OmnichannelCrm::Workflow.where(account_id: run.account_id).where.not(id: current_workflow.id)
                            .find { |workflow| comparable_name(workflow.name) == wanted && workflow.start_node }
  end

  def missing_subflow_handle
    %w[error success].find { |handle| next_node_id(current_node, handle) } || 'missing'
  end

  def subflow_payload(raw)
    parsed = raw.is_a?(String) ? JSON.parse(raw.presence || '{}') : raw
    parsed.is_a?(Hash) ? template.value(parsed) : {}
  rescue JSON::ParserError
    {}
  end

  def frame_here
    { 'workflow_id' => current_workflow.id, 'node_id' => current_node['id'] }
  end

  def call_stack
    Array(run.variables['__stack'])
  end
end
