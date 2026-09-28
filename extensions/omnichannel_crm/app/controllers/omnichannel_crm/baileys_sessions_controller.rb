class OmnichannelCrm::BaileysSessionsController < OmnichannelCrm::ApplicationController
  before_action -> { authorize_crm!('integrations.manage') }

  def show
    # A bridge restart preserves the WhatsApp credentials, but an interrupted
    # inbox setup may leave that session without its callback. Re-applying this
    # idempotent configuration lets the setup screen repair the binding instead
    # of leaving a connected number unable to receive messages.
    configure_inbox!
    render json: bridge.session(session_id)
  rescue StandardError
    render json: { status: 'not_started' }
  end

  def create
    begin
      bridge.create_session(session_id)
    rescue StandardError
      bridge.session(session_id)
    end
    configure_inbox!
    render json: bridge.session(session_id), status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def refresh
    # Renewing the QR intentionally resets only the linked-device session. The
    # inbox and its conversations remain in Chatwoot.
    bridge.delete_session(session_id)
    bridge.create_session(session_id)
    configure_inbox!
    render json: bridge.session(session_id), status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    target_id = session_id
    bridge.delete_session(target_id)
    channel = current_account.channels.where("additional_attributes ->> 'session_id' = ?", target_id).first
    if channel
      channel.additional_attributes.delete('session_id')
      channel.save!
    end
    head :no_content
  rescue StandardError => e
    return head :no_content if e.message.to_s.include?('404') || e.message.to_s.include?('not found')

    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def bridge
    @bridge ||= OmnichannelCrm::BaileysBridgeClient.new
  end

  def session_id
    return params[:session_id] if params[:session_id].present?
    return inbox_session_id if params[:inbox_id].present?

    key = params[:session_key].presence || 'default'
    "account-#{current_account.id}-session-#{key}"
  end

  def inbox_session_id
    inbox = current_account.inboxes.find(params[:inbox_id])
    inbox.channel.additional_attributes['session_id'].presence || "account-#{current_account.id}-inbox-#{inbox.id}"
  end

  def configure_inbox!
    target_session_id = session_id
    channel = find_target_channel(target_session_id)
    return unless channel&.inbox&.account_id == current_account.id

    channel.additional_attributes = (channel.additional_attributes || {}).merge(
      'provider' => 'baileys',
      'session_id' => target_session_id
    )
    channel.save!

    callback = "#{ENV.fetch('BAILEYS_CHATWOOT_CALLBACK_URL', 'http://rails:3000/api/v1/baileys')}/#{target_session_id}/messages"
    channel.update!(webhook_url: nil)
    bridge.configure_webhook(target_session_id, callback, channel.secret)

    return if bridge.session(target_session_id).fetch('webhook_configured', false)

    raise 'Não foi possível configurar o callback de mensagens da sessão Baileys'
  end

  def find_target_channel(target_session_id)
    return current_account.inboxes.find_by(id: params[:inbox_id])&.channel if params[:inbox_id].present?

    Channel::Api.where("additional_attributes ->> 'session_id' = ?", target_session_id).first
  end
end
