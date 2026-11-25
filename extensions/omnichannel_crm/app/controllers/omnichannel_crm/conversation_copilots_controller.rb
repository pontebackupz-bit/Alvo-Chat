# "Perguntar ao Copiloto" for anyone who can open the conversation.
class OmnichannelCrm::ConversationCopilotsController < OmnichannelCrm::ApplicationController
  before_action :set_conversation

  def create
    answer = OmnichannelCrm::ConversationCopilot.new(conversation: @conversation, user: current_user)
                                               .ask(params[:question], params.permit(history: %i[role content]).fetch(:history, []))
    render json: { answer: answer }
  rescue OmnichannelCrm::ConversationCopilot::Unavailable, ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.warn("Copilot failed for conversation #{@conversation.id}: #{e.class} #{e.message}")
    render json: { error: 'O Copiloto não conseguiu responder agora. Tente de novo em instantes.' }, status: :bad_gateway
  end

  private

  def set_conversation
    @conversation = current_account.conversations.find_by!(display_id: params[:conversation_id])
    context = { user: current_user, account: current_account, account_user: Current.account_user }
    head :forbidden unless ConversationPolicy.new(context, @conversation).show?
  end
end
