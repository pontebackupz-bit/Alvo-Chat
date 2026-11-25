# Location, contact, poll and option list from the reply box.
class OmnichannelCrm::RichMessagesController < OmnichannelCrm::ApplicationController
  def create
    conversation = current_account.conversations.find_by!(display_id: params[:conversation_id])
    context = { user: current_user, account: current_account, account_user: Current.account_user }
    return head :forbidden unless ConversationPolicy.new(context, conversation).show?

    message = OmnichannelCrm::WhatsappRichMessage.new(conversation: conversation, user: current_user, params: params).create!
    render json: { id: message.id }, status: :created
  rescue OmnichannelCrm::WhatsappRichMessage::Invalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
