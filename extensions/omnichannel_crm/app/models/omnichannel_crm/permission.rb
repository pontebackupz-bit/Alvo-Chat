module OmnichannelCrm
  class Permission < ApplicationRecord
    self.table_name = 'crm_permissions'

    has_many :role_permissions, dependent: :destroy
    has_many :roles, through: :role_permissions

    validates :key, :name, presence: true
    validates :key, uniqueness: true
  end
end
