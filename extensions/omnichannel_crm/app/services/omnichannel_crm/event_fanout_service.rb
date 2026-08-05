class OmnichannelCrm::EventFanoutService
  def initialize(event_name:, account:, payload:)
    @event_name = event_name
    @account = account
    @payload = payload
  end

  def perform
    log_event
    matching_rules.each { |rule| queue(rule) }
  end

  private

  def matching_rules
    OmnichannelCrm::AutomationRule.where(account: @account, event_name: @event_name, active: true)
                                  .includes(:n8n_connection).select do |rule|
      next false unless rule.n8n_connection.active?

      matches_filters?(rule.filters)
    end
  end

  def matches_filters?(filters)
    filters.blank? || filters.all? { |key, value| @payload[key.to_s] == value || @payload[key.to_sym] == value }
  end

  def queue(rule)
    execution = OmnichannelCrm::WorkflowExecution.create!(
      account: @account, automation_rule: rule, n8n_connection: rule.n8n_connection,
      workflow_id: rule.workflow_id, webhook_path: rule.webhook_path, trigger: @event_name,
      request_payload: @payload, status: :queued
    )
    OmnichannelCrm::TriggerWorkflowJob.perform_later(execution.id)
  end

  def log_event
    OmnichannelCrm::AuditLog.create!(account: @account, event_type: "event.#{@event_name}", metadata: @payload)
  end
end
