module OmnichannelCrm
  class Workflow < ApplicationRecord
    self.table_name = 'crm_workflows'

    belongs_to :account, class_name: '::Account'

    validates :name, :source, presence: true
    validates :nodes, :connections, :variables, :metadata, :import_report, presence: true
    validates :source, inclusion: { in: %w[native ezchat n8n] }
  end
end
