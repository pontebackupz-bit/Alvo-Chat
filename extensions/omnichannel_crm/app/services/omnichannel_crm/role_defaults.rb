module OmnichannelCrm
  class RoleDefaults
    DEFINITIONS = {
      administrator: { name: 'Administrador CRM', permissions: ['*'] },
      supervisor: {
        name: 'Supervisor',
        permissions: %w[leads.read leads.manage dashboards.read distribution.manage automation.manage audit.read]
      },
      seller: { name: 'Vendedor', permissions: %w[leads.read leads.manage] }
    }.freeze

    def self.install(account)
      permissions = Permission.where(key: all_permission_keys).index_by(&:key)
      DEFINITIONS.each do |key, definition|
        role = Role.find_or_create_by!(account: account, key: key) { |record| record.name = definition[:name] }
        role.permissions = definition[:permissions].map { |permission| permissions.fetch(permission) }
      end
    end

    def self.all_permission_keys
      (DEFINITIONS.values.flat_map { |definition| definition[:permissions] } + available_permissions.keys).uniq
    end

    def self.available_permissions
      {
        '*' => 'Acesso completo ao CRM',
        'leads.read' => 'Visualizar leads',
        'leads.manage' => 'Gerenciar leads',
        'dashboards.read' => 'Visualizar dashboards',
        'distribution.manage' => 'Gerenciar distribuição',
        'automation.manage' => 'Gerenciar automações',
        'audit.read' => 'Visualizar auditoria',
        'integrations.manage' => 'Gerenciar integrações',
        'settings.manage' => 'Gerenciar configurações',
        'users.manage' => 'Gerenciar usuários',
        'teams.manage' => 'Gerenciar equipes'
      }
    end

    def self.install_permissions!
      available_permissions.each { |key, name| Permission.find_or_create_by!(key: key) { |record| record.name = name } }
    end
  end
end
