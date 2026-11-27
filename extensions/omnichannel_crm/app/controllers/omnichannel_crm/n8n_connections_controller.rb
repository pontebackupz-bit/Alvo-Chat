module OmnichannelCrm
  class N8nConnectionsController < ApplicationController
    before_action -> { authorize_crm!('integrations.manage') }

    rescue_from N8n::Client::RequestError do |error|
      render json: { error: error.message }, status: :unprocessable_entity
    end

    def index
      render json: N8nConnection.where(account: current_account), except: %i[api_key webhook_auth_value]
    end

    def create
      connection = N8nConnection.create!(connection_params.merge(account: current_account))
      audit!('n8n_connection.created', subject: connection)
      render json: connection, except: %i[api_key webhook_auth_value], status: :created
    end

    def update
      connection = find_connection
      connection.update!(connection_params)
      audit!('n8n_connection.updated', subject: connection)
      render json: connection, except: %i[api_key webhook_auth_value]
    end

    def destroy
      connection = find_connection
      connection.destroy!
      audit!('n8n_connection.deleted', subject: connection)
      head :no_content
    end

    def workflows
      render json: n8n_client.workflows
    end

    def workflow
      render json: n8n_client.workflow(params[:workflow_id])
    end

    def create_workflow
      workflow = n8n_client.create_workflow(workflow_params)
      audit!('n8n_workflow.created', subject: find_connection, metadata: { workflow_id: workflow['id'] })
      render json: workflow, status: :created
    end

    def update_workflow
      workflow = n8n_client.update_workflow(params[:workflow_id], workflow_params)
      audit!('n8n_workflow.updated', subject: find_connection, metadata: { workflow_id: params[:workflow_id] })
      render json: workflow
    end

    def activate_workflow
      active = ActiveModel::Type::Boolean.new.cast(params.fetch(:active))
      workflow = n8n_client.set_workflow_active(params[:workflow_id], active)
      event_type = active ? 'n8n_workflow.activated' : 'n8n_workflow.deactivated'
      audit!(event_type, subject: find_connection, metadata: { workflow_id: params[:workflow_id] })
      render json: workflow
    end

    def executions
      render json: WorkflowExecution.where(n8n_connection: find_connection).order(created_at: :desc)
    end

    def execute_workflow
      execution = WorkflowExecution.create!(account: current_account, n8n_connection: find_connection,
                                            workflow_id: params[:workflow_id], webhook_path: params.require(:webhook_path),
                                            status: :queued, trigger: 'manual',
                                            request_payload: params.permit(payload: {}).fetch(:payload, {}))
      TriggerWorkflowJob.perform_later(execution.id)
      audit!('n8n_workflow.queued', subject: execution, metadata: { workflow_id: execution.workflow_id })
      render json: execution, status: :accepted
    end

    private

    def find_connection
      @find_connection ||= N8nConnection.where(account: current_account, active: true).find(params[:id])
    end

    def n8n_client
      N8n::Client.new(find_connection)
    end

    # Nodes and connections are arbitrary n8n JSON, forwarded with the connection's own API key.
    def workflow_params
      params.require(:workflow).to_unsafe_h
    end

    def connection_params
      params.require(:n8n_connection).permit(:name, :base_url, :api_key, :active, :webhook_auth_header, :webhook_auth_value)
    end
  end
end
