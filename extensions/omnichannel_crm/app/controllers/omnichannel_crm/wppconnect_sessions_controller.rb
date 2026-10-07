class OmnichannelCrm::WppconnectSessionsController < OmnichannelCrm::ApplicationController
  before_action -> { authorize_crm!('integrations.manage') }

  def show
    render json: public_session(bridge.session(session_id))
  rescue StandardError
    render json: { status: 'not_started' }
  end

  def create
    bridge.create_session(session_id)
    configure_inbox! if params[:inbox_id].present?
    render json: public_session(bridge.session(session_id)), status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def refresh
    bridge.delete_session(session_id)
    bridge.create_session(session_id)
    render json: public_session(bridge.session(session_id)), status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    bridge.delete_session(session_id)
    head :no_content
  rescue StandardError => e
    return head :no_content if e.message.to_s.include?('404') || e.message.to_s.include?('not found')

    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def bridge
    @bridge ||= OmnichannelCrm::WppconnectBridgeClient.new
  end

  def session_id
    return params[:session_id] if params[:session_id].present?
    return inbox_session_id if params[:inbox_id].present?

    key = params[:session_key].presence || 'default'
    "account-#{current_account.id}-wppconnect-#{key}"
  end

  def inbox_session_id
    inbox = current_account.inboxes.find(params[:inbox_id])
    inbox.channel.additional_attributes['session_id'].presence || "account-#{current_account.id}-inbox-#{inbox.id}"
  end

  def configure_inbox!
    channel = current_account.inboxes.find(params[:inbox_id]).channel
    channel.additional_attributes = (channel.additional_attributes || {}).merge(
      'provider' => 'wppconnect',
      'session_id' => session_id
    )
    channel.save!
  end

  def public_session(session)
    status = session['status'].to_s.downcase
    {
      id: session_id,
      status: %w[connected islogged].include?(status) ? 'connected' : status.presence || 'connecting',
      qr: session['qrcode'],
      updated_at: Time.current.iso8601
    }
  end
end
