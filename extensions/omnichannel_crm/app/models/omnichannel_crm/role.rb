module OmnichannelCrm
  class Role < ApplicationRecord
    self.table_name = 'crm_roles'

    belongs_to :account, class_name: '::Account'
    has_many :role_permissions, dependent: :destroy
    has_many :permissions, through: :role_permissions
    has_many :role_assignments, dependent: :destroy

    validates :name, :key, presence: true
    validates :key, uniqueness: { scope: :account_id }

    def permission_keys
      permissions.pluck(:key)
    end
  end
end
