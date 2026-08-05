module OmnichannelCrm
  class WorkflowExecutionService
    def initialize(execution)
      @execution = execution
    end

    def perform
      @execution.running!
      response = N8n::Client.new(@execution.n8n_connection).execute_webhook(@execution.webhook_path, @execution.request_payload)
      @execution.update!(status: :succeeded, response_payload: response, completed_at: Time.current)
    rescue StandardError => e
      @execution.update!(status: :failed, error_message: e.message, completed_at: Time.current)
      raise
    end
  end
end
