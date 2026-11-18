# frozen_string_literal: true

module OmnichannelCrm
  class Engine < ::Rails::Engine
    isolate_namespace OmnichannelCrm

    initializer 'omnichannel_crm.append_migrations' do |app|
      next if app.root.to_s.match?(root.to_s)

      config.paths['db/migrate'].expanded.each { |path| app.config.paths['db/migrate'] << path }
    end

    config.to_prepare do
      extension = OmnichannelCrm::AsyncDispatcherExtension
      AsyncDispatcher.prepend(extension) unless AsyncDispatcher.ancestors.include?(extension)

      inbox_access = OmnichannelCrm::UserInboxAccess
      User.prepend(inbox_access) unless User.ancestors.include?(inbox_access)

      scope = OmnichannelCrm::SupervisorConversationScope
      { Conversations::PermissionFilterService => scope::PermissionFilter,
        ConversationPolicy => scope::Policy,
        SearchService => scope::Search,
        DataImport::ContactManager => OmnichannelCrm::ContactImportDedup::Manager,
        DataImportJob => OmnichannelCrm::ContactImportDedup::Job }.each do |target, mod|
        target.prepend(mod) unless target.ancestors.include?(mod)
      end
    end
  end
end
