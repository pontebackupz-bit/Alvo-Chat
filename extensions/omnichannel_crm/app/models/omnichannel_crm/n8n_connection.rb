require 'uri'

module OmnichannelCrm
  class N8nConnection < ApplicationRecord
    self.table_name = 'crm_n8n_connections'

    belongs_to :account, class_name: '::Account'
    has_many :automation_rules, dependent: :destroy
    has_many :workflow_executions, dependent: :destroy

    encrypts :api_key, :webhook_auth_value

    validates :name, :base_url, :api_key, presence: true
    validates :name, uniqueness: { scope: :account_id }
    validates :base_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  end
end
