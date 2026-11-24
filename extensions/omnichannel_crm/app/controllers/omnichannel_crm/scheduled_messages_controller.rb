# Messages to be sent later. Anyone who can open a conversation can schedule
# in it; the list shows the scheduled messages of the conversations the user
# can see; cancelling is for the author, supervisors and administrators.
class OmnichannelCrm::ScheduledMessagesController < OmnichannelCrm::ApplicationController
  PAGE_SIZE = 50

  def index
    scope = OmnichannelCrm::ScheduledMessage.where(account_id: current_account.id, conversation_id: visible_conversations.select(:id))
    scope = scope.where(status: params[:status]) if OmnichannelCrm::ScheduledMessage.statuses.key?(params[:status].to_s)
    scope = scope.where(conversation_id: conversation.id) if params[:conversation_id].present?
    order = params[:status] == 'pending' ? { scheduled_at: :asc } : { scheduled_at: :desc }
    records = scope.order(order).limit(PAGE_SIZE).includes(:user, conversation: :contact)
    render json: { scheduled_messages: records.map { |record| row(record) } }
  end

  def create
    record = OmnichannelCrm::ScheduledMessage.create!(
      account_id: current_account.id, conversation: conversation, user: current_user,
      content: params[:content].to_s.strip, scheduled_at: Time.zone.parse(params[:scheduled_at].to_s)
    )
    render json: row(record), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def destroy
    record = OmnichannelCrm::ScheduledMessage.where(account_id: current_account.id, conversation_id: visible_conversations.select(:id))
                                             .find(params[:id])
    return render json: { error: 'Só quem agendou, supervisores e administradores podem cancelar.' }, status: :forbidden unless can_cancel?(record)
    return render json: { error: 'Esta mensagem já foi enviada.' }, status: :unprocessable_entity unless record.pending?

    record.update!(status: :cancelled)
    head :no_content
  end

  private

  def visible_conversations
    @visible_conversations ||= Conversations::PermissionFilterService.new(current_account.conversations, current_user, current_account).perform
  end

  def conversation
    @conversation ||= visible_conversations.find_by!(display_id: params[:conversation_id])
  end

  def can_cancel?(record)
    record.user_id == current_user.id || authorization.supervisor? ||
      current_account.account_users.find_by(user_id: current_user.id)&.administrator?
  end

  def row(record)
    contact = record.conversation.contact
    {
      id: record.id, content: record.content, status: record.status, scheduled_at: record.scheduled_at,
      sent_at: record.sent_at, error: record.error_message, can_cancel: record.pending? && can_cancel?(record),
      author: record.user&.name,
      conversation: { id: record.conversation.display_id, contact: contact&.name, phone: contact&.phone_number }
    }
  end
end
