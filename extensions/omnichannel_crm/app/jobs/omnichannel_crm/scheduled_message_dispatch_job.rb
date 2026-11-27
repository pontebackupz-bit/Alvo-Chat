# Runs every minute: sends the scheduled messages that are due.
class OmnichannelCrm::ScheduledMessageDispatchJob < ApplicationJob
  queue_as :default

  def perform
    OmnichannelCrm::ScheduledMessage.due.order(:scheduled_at).limit(200).find_each(&:deliver!)
  end
end
