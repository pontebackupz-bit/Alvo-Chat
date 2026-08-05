module OmnichannelCrm
  class TeamSupervisor < ApplicationRecord
    self.table_name = 'crm_team_supervisors'

    belongs_to :account, class_name: '::Account'
    belongs_to :team, class_name: '::Team'
    belongs_to :user, class_name: '::User'

    validates :user_id, uniqueness: { scope: :team_id }
    validate :team_belongs_to_account

    private

    def team_belongs_to_account
      errors.add(:team, 'must belong to the same account') if team && team.account_id != account_id
      errors.add(:user, 'must belong to the same account') if account && user && !account.users.exists?(id: user_id)
    end
  end
end
