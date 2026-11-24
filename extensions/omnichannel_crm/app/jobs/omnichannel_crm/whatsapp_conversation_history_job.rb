class OmnichannelCrm::WhatsappConversationHistoryJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = ::Conversation.find_by(id: conversation_id)
    return unless conversation

    OmnichannelCrm::WhatsappHistoryImport.new(conversation.inbox).import_conversation(conversation)
  end
end
