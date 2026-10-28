module OmnichannelCrm
  class WorkflowsController < ApplicationController
    MAX_IMPORT_BYTES = 5.megabytes

    before_action -> { authorize_crm!('automation.manage') }

    def index
      render json: Workflow.where(account: current_account).order(updated_at: :desc)
    end

    def show
      render json: find_workflow
    end

    def preview
      render json: WorkflowImporters::Registry.import(import_payload, filename: import_filename)
    rescue WorkflowImporters::ImportError, JSON::ParserError => error
      render json: { error: error.message }, status: :unprocessable_entity
    end

    def import
      definition = WorkflowImporters::Registry.import(import_payload, filename: import_filename)
      workflow = nil
      Workflow.transaction do
        workflow = Workflow.create!(definition.merge(account: current_account))
        audit!('workflow_imported', subject: workflow, metadata: audit_metadata(workflow))
      end
      render json: workflow, status: :created
    rescue WorkflowImporters::ImportError, JSON::ParserError, ActiveRecord::RecordInvalid => error
      render json: { error: error.message }, status: :unprocessable_entity
    end

    def export
      workflow = find_workflow
      filename = workflow.name.parameterize.presence || "workflow-#{workflow.id}"
      send_data JSON.generate(WorkflowExporter.new(workflow).as_json), type: 'application/json',
                filename: "#{filename}.alvo", disposition: 'attachment'
    end

    def update
      workflow = find_workflow
      workflow.update!(workflow_params)
      audit!('workflow_updated', subject: workflow)
      render json: workflow
    end

    private

    def find_workflow
      Workflow.where(account: current_account).find(params[:id])
    end

    def import_file
      file = params.require(:file)
      raise WorkflowImporters::ImportError, 'O arquivo de fluxo excede o limite de 5 MB.' if file.size > MAX_IMPORT_BYTES

      file
    end

    def import_payload
      @import_payload ||= JSON.parse(import_file.read, max_nesting: 100)
    rescue ActionController::ParameterMissing
      raise WorkflowImporters::ImportError, 'Selecione um arquivo .flow ou .json para importar.'
    end

    def import_filename
      import_file.original_filename
    end

    def workflow_params
      params.require(:workflow).permit(:name, :description, nodes: {}, connections: {}, variables: {}, metadata: {})
    end

    def audit_metadata(workflow)
      report = workflow.import_report
      { source: workflow.source, filename: workflow.metadata['filename'], workflow_id: workflow.id,
        nodes_total: report['nodesTotal'], nodes_converted: report['nodesConverted'],
        nodes_unsupported: report['nodesUnsupported'], warnings: report['warnings'].size }
    end
  end
end
