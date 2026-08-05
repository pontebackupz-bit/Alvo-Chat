class OmnichannelCrm::BaileysSessionsController < ApplicationController
  before_action -> { authorize_crm!('integrations.manage') }

  def show
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

  private

  def bridge
    @bridge ||= OmnichannelCrm::BaileysBridgeClient.new
  end

  def session_id
    "account-#{current_account.id}"
  end

  def configure_inbox!
    channel = Channel::Api.where("additional_attributes ->> 'session_id' = ?", session_id).first
    return unless channel&.inbox&.account_id == current_account.id

    callback = "#{ENV.fetch('BAILEYS_CHATWOOT_CALLBACK_URL', 'http://rails:3000/api/v1/baileys')}/#{session_id}/messages"
    channel.update!(webhook_url: nil)
    bridge.configure_webhook(session_id, callback, channel.secret)
  end
end
