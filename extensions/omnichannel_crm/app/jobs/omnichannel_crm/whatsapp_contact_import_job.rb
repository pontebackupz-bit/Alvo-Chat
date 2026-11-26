class OmnichannelCrm::WhatsappContactImportJob < ApplicationJob
  queue_as :low

  def perform(inbox_id)
    inbox = ::Inbox.find_by(id: inbox_id)
    return unless inbox

    OmnichannelCrm::WhatsappContactImport.new(inbox).perform
  rescue StandardError => e
    # The failure is shown on the connection card; no retry storm.
    Rails.logger.warn("WhatsApp contact import job ended: #{e.message}")
  end
end
