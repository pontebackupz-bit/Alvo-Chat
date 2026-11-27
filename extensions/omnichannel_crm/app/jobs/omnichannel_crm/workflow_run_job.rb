class OmnichannelCrm::WorkflowRunJob < ApplicationJob
  queue_as :default

  # `reply_message_id` is the customer's message that answers a question or
  # menu, `inactivity_token` identifies the wait an inactivity timer was set
  # for and `attendance` continues a run after the human attendance ended.
  # Positional so the arguments stay plain in the queue.
  def perform(run_id, reply_message_id = nil, inactivity_token = nil, attendance = false) # rubocop:disable Style/OptionalBooleanParameter
    run = OmnichannelCrm::WorkflowRun.find_by(id: run_id)
    return unless run

    reply = reply_message_id && ::Message.find_by(id: reply_message_id)
    OmnichannelCrm::WorkflowRunner.new(run).perform(reply: reply, inactivity_token: inactivity_token, attendance: attendance)
  end
end
