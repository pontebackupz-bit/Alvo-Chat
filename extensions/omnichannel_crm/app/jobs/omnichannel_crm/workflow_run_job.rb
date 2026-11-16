class OmnichannelCrm::WorkflowRunJob < ApplicationJob
  queue_as :default

  # `reply_message_id` is the customer's message that answers a question or menu.
  def perform(run_id, reply_message_id = nil)
    run = OmnichannelCrm::WorkflowRun.find_by(id: run_id)
    return unless run

    OmnichannelCrm::WorkflowRunner.new(run).perform(reply: reply_message_id && ::Message.find_by(id: reply_message_id))
  end
end
