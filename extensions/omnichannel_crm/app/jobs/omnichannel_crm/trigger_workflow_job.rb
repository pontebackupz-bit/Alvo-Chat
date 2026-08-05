module OmnichannelCrm
  class TriggerWorkflowJob < ::ApplicationJob
    queue_as :default

    def perform(execution_id)
      WorkflowExecutionService.new(WorkflowExecution.find(execution_id)).perform
    end
  end
end
