# Loads a conversation's whole WhatsApp history on demand, for anyone who can
# open the conversation.
class OmnichannelCrm::ConversationHistoriesController < OmnichannelCrm::ApplicationController
  before_action :set_conversation

  def show
    render json: @conversation.additional_attributes.to_h['whatsapp_history'] || {}
  end

  def create
    unless OmnichannelCrm::ConnectionsService.provider(@conversation.inbox) == 'wppconnect'
      return render json: { error: 'Só conversas de números conectados por QR Code têm histórico no WhatsApp.' },
                    status: :unprocessable_entity
    end

    unless OmnichannelCrm::WhatsappHistoryImport.online?(@conversation.inbox)
      return render json: { error: OmnichannelCrm::WhatsappHistoryImport::OFFLINE_MESSAGE }, status: :unprocessable_entity
    end

    attributes = @conversation.additional_attributes.to_h
    @conversation.update_columns(additional_attributes: attributes.merge('whatsapp_history' => { 'status' => 'queued' }))
    OmnichannelCrm::WhatsappConversationHistoryJob.perform_later(@conversation.id)
    head :accepted
  end

  private

  def set_conversation
    @conversation = current_account.conversations.find_by!(display_id: params[:conversation_id])
    context = { user: current_user, account: current_account, account_user: Current.account_user }
    head :forbidden unless ConversationPolicy.new(context, @conversation).show?
  end
end
