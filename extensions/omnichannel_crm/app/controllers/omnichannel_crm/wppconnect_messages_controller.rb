class OmnichannelCrm::WppconnectMessagesController < OmnichannelCrm::BaileysMessagesController
  skip_before_action :authenticate_bridge!
  before_action :authenticate_wppconnect!

  def create
    return head :accepted unless params[:event] == 'onmessage' && !ActiveModel::Type::Boolean.new.cast(params[:fromMe])
    return head :unprocessable_entity if contact_source_id.blank?

    super
  end

  private

  def authenticate_wppconnect!
    expected_token = ENV.fetch('WPPCONNECT_WEBHOOK_TOKEN')
    return if ActiveSupport::SecurityUtils.secure_compare(params[:token].to_s, expected_token)

    head :unauthorized
  end

  def contact_source_id
    @contact_source_id ||= params[:from].to_s.split('@').first.gsub(/\D/, '')
  end

  def inbox
    @inbox ||= Channel::Api.where("additional_attributes ->> 'session_id' = ?", params.require(:session)).first!.inbox
  end

  def phone_number
    @phone_number ||= contact_source_id
  end

  def message_source_id
    raw_message_id = params[:id]
    @message_source_id ||= raw_message_id.is_a?(ActionController::Parameters) ? raw_message_id[:_serialized].presence : raw_message_id
  end

  def content
    params[:body].presence || super
  end
end
