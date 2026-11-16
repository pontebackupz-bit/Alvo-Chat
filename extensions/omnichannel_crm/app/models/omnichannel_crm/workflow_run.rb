class OmnichannelCrm::WorkflowRun < OmnichannelCrm::ApplicationRecord
  self.table_name = 'crm_workflow_runs'

  ACTIVE_STATUSES = %w[running waiting_reply waiting_delay].freeze

  belongs_to :account, class_name: '::Account'
  belongs_to :workflow, class_name: 'OmnichannelCrm::Workflow'
  belongs_to :conversation, class_name: '::Conversation'

  enum :status, %w[running waiting_reply waiting_delay completed cancelled failed].index_by(&:itself)

  scope :active, -> { where(status: ACTIVE_STATUSES) }

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def self.cancel_for(conversation)
    active.find_by(conversation_id: conversation.id)&.update!(status: :cancelled)
  end
end
