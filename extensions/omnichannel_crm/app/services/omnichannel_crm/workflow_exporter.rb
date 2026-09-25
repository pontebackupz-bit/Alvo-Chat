module OmnichannelCrm
  class WorkflowExporter
    SCHEMA = WorkflowImporters::NativeWorkflowImporter::SCHEMA
    VERSION = 1

    def initialize(workflow)
      @workflow = workflow
    end

    def as_json(*)
      {
        schema: SCHEMA, version: VERSION,
        workflow: {
          name: @workflow.name, description: @workflow.description, sourceWorkflowId: @workflow.source_workflow_id,
          nodes: @workflow.nodes, connections: @workflow.connections, variables: @workflow.variables,
          metadata: export_metadata
        }
      }
    end

    private

    def export_metadata
      @workflow.metadata.except('filename').merge('exportedAt' => Time.current.iso8601, 'sourceWorkflowId' => @workflow.id)
    end
  end
end
