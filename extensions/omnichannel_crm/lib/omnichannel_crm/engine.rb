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
        MessageFinder => OmnichannelCrm::MessageFinderChronology,
        ConversationFinder => OmnichannelCrm::AttendanceFilters::Finder,
        DataImport::ContactManager => OmnichannelCrm::ContactImportDedup::Manager,
        DataImportJob => OmnichannelCrm::ContactImportDedup::Job,
        Attachment => OmnichannelCrm::AttachmentAudioUrl,
        Conversation => OmnichannelCrm::ResolutionAuthor::Activity,
        Api::V2::Accounts::ReportsHelper => OmnichannelCrm::AgentReportsWithoutAdministrators,
        AutoAssignment::AgentAssignmentService => OmnichannelCrm::AdministratorsNotAutoAssigned::AgentAssignment,
        AutoAssignment::AssignmentService => OmnichannelCrm::AdministratorsNotAutoAssigned::AssignmentV2 }.each do |target, mod|
        target.prepend(mod) unless target.ancestors.include?(mod)
      end

      # AI features on Groq when GROQ_API_KEY is set (see OmnichannelCrm::GroqLlm).
      groq = OmnichannelCrm::GroqLlm
      Llm::Config.singleton_class.prepend(groq::Config) unless Llm::Config.singleton_class <= groq::Config
      Captain::BaseTaskService.prepend(groq::TaskService) unless Captain::BaseTaskService <= groq::TaskService
      if defined?(Llm::BaseAiService) && !(Llm::BaseAiService <= groq::BaseAiService)
        Llm::BaseAiService.prepend(groq::BaseAiService)
      end
    end
  end
end
