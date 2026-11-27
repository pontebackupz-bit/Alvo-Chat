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

    def create
      workflow = Workflow.create!(workflow_params.merge(account: current_account, source: 'native'))
      audit!('workflow_created', subject: workflow)
      render json: workflow, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
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

    def metrics
      start_at = params[:start_at].present? ? Time.zone.parse(params[:start_at]) : 30.days.ago
      end_at = params[:end_at].present? ? Time.zone.parse(params[:end_at]) : Time.current
      render json: WorkflowMetricsService.new(workflow: find_workflow, range: start_at..end_at).perform
    end

    def readiness
      render json: { issues: WorkflowReadinessService.new(find_workflow).perform }
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
    rescue ActiveRecord::RecordInvalid => error
      render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end

    def destroy
      workflow = find_workflow
      workflow.destroy!
      audit!('workflow_deleted', subject: workflow)
      head :no_content
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

    # Nodes, connections and the trigger are free-form flow JSON edited by the flow builder.
    def workflow_params
      attributes = params.require(:workflow)
      attributes.permit(:name, :description, :active).to_h
                .merge(attributes.to_unsafe_h.slice(:nodes, :connections, :trigger_config))
    end

    def audit_metadata(workflow)
      report = workflow.import_report
      { source: workflow.source, filename: workflow.metadata['filename'], workflow_id: workflow.id,
        nodes_total: report['nodesTotal'], nodes_converted: report['nodesConverted'],
        nodes_unsupported: report['nodesUnsupported'], warnings: report['warnings'].size }
    end
  end
end
