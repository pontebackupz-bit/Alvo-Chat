module OmnichannelCrm
  class AuditLog < ApplicationRecord
    self.table_name = 'crm_audit_logs'

    belongs_to :account, class_name: '::Account'
    belongs_to :actor, class_name: '::User', optional: true

    validates :event_type, presence: true
  end
end
