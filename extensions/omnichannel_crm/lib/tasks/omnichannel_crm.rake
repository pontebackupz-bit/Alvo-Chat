namespace :omnichannel_crm do
  desc 'Install default CRM permissions and roles for ACCOUNT_ID'
  task seed_roles: :environment do
    account_id = ENV.fetch('ACCOUNT_ID')
    OmnichannelCrm::RoleDefaults.install_permissions!
    OmnichannelCrm::RoleDefaults.install(Account.find(account_id))
  end
end
