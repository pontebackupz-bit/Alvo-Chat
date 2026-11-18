module OmnichannelCrm
  class Workflow < ApplicationRecord
    self.table_name = 'crm_workflows'

    belongs_to :account, class_name: '::Account'
    has_many :runs, class_name: 'OmnichannelCrm::WorkflowRun', dependent: :destroy

    validates :name, :source, presence: true
    validates :source, inclusion: { in: %w[native ezchat n8n] }
    validate :runnable, if: :active?

    scope :active, -> { where(active: true) }

    def start_node
      nodes.find { |node| node['type'] == 'start' }
    end

    def starts_on_new_conversation?(inbox_id)
      inbox_ids = Array(trigger_config['inbox_ids']).map(&:to_i)
      inbox_ids.empty? || inbox_ids.include?(inbox_id)
    end

    private

    def runnable
      errors.add(:base, 'Um fluxo ativo precisa de exatamente um bloco de início.') unless nodes.count { |node| node['type'] == 'start' } == 1

      unsupported = nodes.pluck('type').uniq - WorkflowRunner::NODE_TYPES - WorkflowRunner::PASSIVE_TYPES
      errors.add(:base, "Blocos sem suporte para execução: #{unsupported.join(', ')}.") if unsupported.any?
    end
  end
end
