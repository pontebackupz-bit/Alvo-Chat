module OmnichannelCrm
  class AutomationRule < ApplicationRecord
    self.table_name = 'crm_automation_rules'

    belongs_to :account, class_name: '::Account'
    belongs_to :n8n_connection
    has_many :workflow_executions, dependent: :destroy

    validates :name, :event_name, :workflow_id, :webhook_path, presence: true
    validates :event_name, inclusion: { in: OmnichannelCrm::EVENT_NAMES }
    validate :connection_belongs_to_account

    private

    def connection_belongs_to_account
      errors.add(:n8n_connection, 'must belong to the same account') if n8n_connection && n8n_connection.account_id != account_id
    end
  end
end
