module OmnichannelCrm
  class WorkflowExecution < ApplicationRecord
    self.table_name = 'crm_workflow_executions'

    belongs_to :account, class_name: '::Account'
    belongs_to :n8n_connection
    belongs_to :automation_rule, optional: true

    enum :status, { queued: 0, running: 1, succeeded: 2, failed: 3 }, prefix: true
  end
end
