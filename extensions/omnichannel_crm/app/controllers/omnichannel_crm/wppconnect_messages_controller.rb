class OmnichannelCrm::WppconnectMessagesController < OmnichannelCrm::BaileysMessagesController
  skip_before_action :authenticate_bridge!
  before_action :authenticate_wppconnect!

  def create
    return head :accepted unless params[:event] == 'onmessage' && !ActiveModel::Type::Boolean.new.cast(params[:fromMe])
    return head :accepted if phone_number.blank?

    super
  end

  private

  def authenticate_wppconnect!
    expected_token = ENV.fetch('WPPCONNECT_WEBHOOK_TOKEN')
    return if ActiveSupport::SecurityUtils.secure_compare(params[:token].to_s, expected_token)

    head :unauthorized
  end

  def contact_source_id
    @contact_source_id ||= phone_number
  end

  def inbox
    @inbox ||= Channel::Api.where("additional_attributes ->> 'session_id' = ?", session_id).first!.inbox
  end

  def phone_number
    return @phone_number if defined?(@phone_number)

    @phone_number = lid? ? bridge.phone_number_for(session_id, params[:from].to_s) : jid_user(params[:from])
  rescue StandardError => e
    Rails.logger.warn("Unable to map WPPConnect LID to a phone number: #{e.message}")
    @phone_number = nil
  end

  def contact_inbox_with_phone_number
    super || migrate_lid_contact
  end

  def message_source_id
    raw_message_id = params[:id]
    @message_source_id ||= raw_message_id.is_a?(ActionController::Parameters) ? raw_message_id[:_serialized].presence : raw_message_id
  end

  def content
    return params[:caption].presence || '' if media?

    params[:body].presence || super
  end

  def media_params
    return super unless media?

    @media_params ||= ActionController::Parameters.new(
      data: media_data,
      file_type: media_file_type,
      mime_type: mime_type,
      file_name: media_file_name,
      is_sticker: sticker_message?,
      is_animated_sticker: animated_sticker_message?,
      is_voice_message: params[:type].to_s == 'ptt'
    ).permit!
  end

  def lid?
    params[:from].to_s.end_with?('@lid')
  end

  def bridge
    @bridge ||= OmnichannelCrm::WppconnectBridgeClient.new
  end

  def session_id
    params.require(:session)
  end

  def jid_user(jid)
    jid.to_s.split('@').first.gsub(/\D/, '').presence
  end

  def media?
    params[:isMedia] == true || params[:isMedia] == 'true' || mime_type.start_with?('image/', 'video/', 'audio/') ||
      %w[document sticker gif image video audio ptt].include?(params[:type].to_s)
  end

  def media_data
    params[:body].to_s.sub(%r{\Adata:[^;]+;base64,}, '')
  end

  def mime_type
    @mime_type ||= params[:mimetype].presence || (sticker_message? ? 'image/webp' : 'application/octet-stream')
  end

  def media_file_type
    return 'image' if sticker_message? || mime_type.start_with?('image/')
    return 'video' if mime_type.start_with?('video/')
    return 'audio' if mime_type.start_with?('audio/')

    'file'
  end

  def media_file_name
    return params[:filename] if params[:filename].present?

    extension = mime_type.split('/').last.presence || 'bin'
    "whatsapp-#{params[:type].presence || 'arquivo'}.#{extension}"
  end

  def sticker_message?
    params[:type].to_s == 'sticker'
  end

  def animated_sticker_message?
    sticker_message? && ActiveModel::Type::Boolean.new.cast(params[:isAnimated])
  end

  def migrate_lid_contact
    return unless lid?

    contact_inbox = inbox.contact_inboxes.find_by(source_id: jid_user(params[:from]))
    return unless contact_inbox

    attributes = { phone_number: "+#{phone_number}" }
    attributes[:name] = phone_number if contact_inbox.contact.name == jid_user(params[:from])
    contact_inbox.contact.update!(attributes)
    contact_inbox.update!(source_id: phone_number)
    contact_inbox
  end
end
