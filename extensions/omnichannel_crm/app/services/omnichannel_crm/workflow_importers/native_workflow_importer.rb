module OmnichannelCrm
  module WorkflowImporters
    class NativeWorkflowImporter
      SCHEMA = 'comercial-alvorada.workflow'.freeze

      def self.can_import?(payload, filename: nil)
        payload.is_a?(Hash) && payload['schema'] == SCHEMA && payload['workflow'].is_a?(Hash)
      end

      def initialize(payload, filename:)
        @payload = payload
      end

      def import
        workflow = @payload.fetch('workflow')
        validate!(workflow)
        {
          name: workflow.fetch('name'), description: workflow['description'].to_s, source: 'native',
          source_workflow_id: workflow['sourceWorkflowId'], nodes: workflow.fetch('nodes'),
          connections: workflow.fetch('connections'), variables: workflow.fetch('variables', []),
          metadata: workflow.fetch('metadata', {}).merge('importSource' => 'native', 'importedAt' => Time.current.iso8601),
          import_report: { 'nodesTotal' => workflow['nodes'].size, 'nodesConverted' => workflow['nodes'].size,
                           'nodesUnsupported' => 0, 'credentialsRequired' => 0, 'subflowsPending' => 0,
                           'connectionsTotal' => workflow['connections'].size, 'connectionsConverted' => workflow['connections'].size,
                           'connectionsInvalid' => 0, 'warnings' => [] }
        }
      end

      private

      def validate!(workflow)
        raise ImportError, 'O arquivo .alvo não contém um nome de fluxo válido.' if workflow['name'].blank?
        raise ImportError, 'O arquivo .alvo não contém nodes válidos.' unless workflow['nodes'].is_a?(Array)
        raise ImportError, 'O arquivo .alvo não contém conexões válidas.' unless workflow['connections'].is_a?(Array)
      end
    end
  end
end
