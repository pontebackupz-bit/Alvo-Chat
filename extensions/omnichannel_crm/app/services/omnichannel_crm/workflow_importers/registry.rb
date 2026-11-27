module OmnichannelCrm
  module WorkflowImporters
    class Registry
      IMPORTERS = [NativeWorkflowImporter, EzChatFlowImporter].freeze

      def self.import(payload, filename:)
        importer = IMPORTERS.find { |candidate| candidate.can_import?(payload, filename: filename) }
        raise ImportError, 'O arquivo enviado não corresponde a um formato de fluxo suportado.' unless importer

        importer.new(payload, filename: filename).import
      end
    end
  end
end
