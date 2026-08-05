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
    end
  end
end
