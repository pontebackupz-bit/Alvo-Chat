module OmnichannelCrm
  class RoleAssignment < ApplicationRecord
    self.table_name = 'crm_role_assignments'

    belongs_to :account, class_name: '::Account'
    belongs_to :role
    belongs_to :user, class_name: '::User'

    validates :user_id, uniqueness: { scope: :account_id }
    validate :role_belongs_to_account

    private

    def role_belongs_to_account
      errors.add(:role, 'must belong to the same account') if role && role.account_id != account_id
      errors.add(:user, 'must belong to the same account') if account && user && !account.users.exists?(id: user_id)
    end
  end
end
