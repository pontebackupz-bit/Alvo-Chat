class OmnichannelCrm::WorkflowRun < OmnichannelCrm::ApplicationRecord
  self.table_name = 'crm_workflow_runs'

  ACTIVE_STATUSES = %w[running waiting_reply waiting_delay waiting_agent].freeze

  belongs_to :account, class_name: '::Account'
  belongs_to :workflow, class_name: 'OmnichannelCrm::Workflow'
  belongs_to :conversation, class_name: '::Conversation'

  enum :status, %w[running waiting_reply waiting_delay waiting_agent completed cancelled failed].index_by(&:itself)

  scope :active, -> { where(status: ACTIVE_STATUSES) }

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  # A run waiting for an attendance to end is not cancelled by the agent's
  # messages; resolving the conversation continues it instead.
  def self.cancel_for(conversation)
    active.where.not(status: :waiting_agent).find_by(conversation_id: conversation.id)&.update!(status: :cancelled)
  end

  def self.finish_attendance_for(conversation)
    run = active.find_by(conversation_id: conversation.id)
    return unless run

    run.waiting_agent? ? OmnichannelCrm::WorkflowRunJob.perform_later(run.id, nil, nil, true) : run.update!(status: :cancelled)
  end
end
