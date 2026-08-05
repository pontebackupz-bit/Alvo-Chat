module OmnichannelCrm
  class DistributionRule < ApplicationRecord
    self.table_name = 'crm_distribution_rules'

    belongs_to :account, class_name: '::Account'
    belongs_to :team, class_name: '::Team', optional: true

    enum :strategy, { round_robin: 0, least_open_conversations: 1 }, prefix: true
    validates :name, :strategy, presence: true
    validate :team_belongs_to_account

    private

    def team_belongs_to_account
      errors.add(:team, 'must belong to the same account') if team && team.account_id != account_id
    end
  end
end
