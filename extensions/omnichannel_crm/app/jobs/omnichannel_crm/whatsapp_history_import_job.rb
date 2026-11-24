class OmnichannelCrm::WhatsappHistoryImportJob < ApplicationJob
  queue_as :low

  def perform(inbox_id, chats = 100, messages_per_chat = 100)
    inbox = ::Inbox.find_by(id: inbox_id)
    return unless inbox

    OmnichannelCrm::WhatsappHistoryImport.new(inbox, chats: chats, messages_per_chat: messages_per_chat).perform
  end
end
