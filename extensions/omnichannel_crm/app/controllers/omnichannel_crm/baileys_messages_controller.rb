require 'base64'
require 'stringio'

class OmnichannelCrm::BaileysMessagesController < ActionController::API
  # Keep the inbound limit aligned with both bridge clients. WhatsApp documents
  # commonly exceed 12 MB; 20 MB remains bounded after Base64 decoding.
  MAX_MEDIA_BYTES = 20.megabytes
  MAX_BASE64_MEDIA_BYTES = ((MAX_MEDIA_BYTES + 2) / 3) * 4

  before_action :authenticate_bridge!

  def create
    return render_existing_message if existing_message
    return head :accepted if from_me? && pending_outgoing_message?
    return head :accepted if csat_reply?

    message = conversation.messages.build(message_attributes)
    attach_media(message)
    message.save!
    OmnichannelCrm::AudioTranscriptionJob.enqueue_for(message)
    render json: { id: message.id }, status: :created
  end

  def update_contact
    contact_inbox = inbox.contact_inboxes.find_by(source_id: params[:source_id])
    return head :not_found unless contact_inbox

    phone_number = params.require(:phone_number)
    attributes = { phone_number: "+#{phone_number}" }
    attributes[:name] = phone_number if contact_inbox.contact.name == params[:source_id]
    contact_inbox.contact.update!(attributes)
    contact_inbox.update!(source_id: phone_number) unless inbox.contact_inboxes.where.not(id: contact_inbox.id).exists?(source_id: phone_number)
    head :no_content
  end

  private

  def inbox
    @inbox ||= Channel::Api.where("additional_attributes ->> 'session_id' = ?", params[:session_id]).first!.inbox
  end

  def existing_message
    @existing_message ||= inbox.messages.find_by(source_id: message_source_id)
  end

  def render_existing_message
    render json: { id: existing_message.id }, status: :ok
  end

  def conversation
    contact_inbox.conversations.open.first || ConversationBuilder.new(params: {}, contact_inbox: contact_inbox).perform
  end

  def contact_inbox
    @contact_inbox ||= contact_inbox_with_phone_number || ContactInboxWithContactBuilder.new(
      source_id: contact_source_id,
      inbox: inbox,
      contact_attributes: {
        name: params[:name].presence || phone_number || contact_source_id,
        phone_number: phone_number.present? ? "+#{phone_number}" : nil
      }
    ).perform.tap { |record| sync_contact(record) }
  end

  def csat_reply?
    return false if from_me? || media_params[:data].present?

    OmnichannelCrm::CsatReplyService.new(contact_inbox: contact_inbox, content: content, source_id: message_source_id).perform
  end

  def message_attributes
    content_attributes = { baileys: { sticker: sticker?, animated_sticker: animated_sticker? } }
    {
      account: inbox.account,
      inbox: inbox,
      # Messages typed on the connected phone are stored like WhatsApp Cloud echoes:
      # outgoing without an agent, flagged as sent from the native app.
      sender: from_me? ? nil : contact_inbox.contact,
      message_type: from_me? ? :outgoing : :incoming,
      status: from_me? ? :delivered : :sent,
      content: content,
      source_id: message_source_id,
      content_type: sticker? ? :sticker : :text,
      content_attributes: from_me? ? content_attributes.merge(external_echo: true) : content_attributes
    }
  end

  def from_me?
    ActiveModel::Type::Boolean.new.cast(params[:from_me])
  end

  # A message sent from the dashboard is echoed back by WhatsApp before the
  # delivery job stores its WhatsApp id, so match it by conversation and content.
  def pending_outgoing_message?
    pending = Message.outgoing.where(conversation_id: contact_inbox.conversations.select(:id), source_id: nil, created_at: 2.minutes.ago..)
                     .where.not(status: :failed)
    pending = pending.where(content: content) if content.present?
    pending.exists?
  end

  def phone_number
    @phone_number ||= params[:phone_number].presence || contact_source_id
  end

  def contact_source_id
    @contact_source_id ||= params[:source_id].presence || params.require(:from).to_s.split('@').first.gsub(/\D/, '')
  end

  def sync_contact(contact_inbox)
    attributes = { custom_attributes: (contact_inbox.contact.custom_attributes || {}).except('baileys_jid') }
    return contact_inbox.contact.update!(attributes) if phone_number.blank? || contact_inbox.contact.phone_number == "+#{phone_number}"

    attributes[:phone_number] = "+#{phone_number}"
    attributes[:name] = phone_number if contact_inbox.contact.name == contact_source_id
    contact_inbox.contact.update!(attributes)
  end

  def contact_inbox_with_phone_number
    return unless phone_number.present?

    inbox.contact_inboxes.joins(:contact).find_by(contacts: { phone_number: "+#{phone_number}" })
  end

  def content
    params[:content].presence || params[:text].presence || ''
  end

  def attach_media(message)
    return if media_params[:data].blank?

    raise ActionController::BadRequest, 'Arquivo de mídia excede o limite permitido' if media_params[:data].bytesize > MAX_BASE64_MEDIA_BYTES

    attachment = build_attachment(message)
    OmnichannelCrm::WhatsappMedia.attach(attachment.file, Base64.strict_decode64(media_params[:data]),
                                         filename: media_params[:file_name].presence || 'arquivo',
                                         mime: media_params[:mime_type])
  end

  def build_attachment(message)
    message.attachments.build(account_id: inbox.account_id, file_type: media_file_type).tap do |attachment|
      attachment.meta = attachment_metadata
    end
  end

  def attachment_metadata
    return { is_sticker: true, is_animated_sticker: animated_sticker? } if sticker?
    return { is_voice_message: true } if voice_message?

    {}
  end

  def media_file_type
    %w[image audio video file].include?(media_params[:file_type]) ? media_params[:file_type] : 'file'
  end

  def media_params
    @media_params ||= params.fetch(:media, {}).permit(
      :data, :file_type, :mime_type, :file_name, :is_sticker, :is_animated_sticker, :is_voice_message
    )
  end

  def sticker?
    boolean_media_value(:is_sticker)
  end

  def animated_sticker?
    boolean_media_value(:is_animated_sticker)
  end

  def voice_message?
    boolean_media_value(:is_voice_message)
  end

  def boolean_media_value(key)
    ActiveModel::Type::Boolean.new.cast(media_params[key])
  end

  def message_source_id
    params.require(:message_id)
  end

  def authenticate_bridge!
    expected_token = "Bearer #{ENV.fetch('BAILEYS_API_TOKEN', 'local-development-token-change-before-production')}"
    return if ActiveSupport::SecurityUtils.secure_compare(request.headers['Authorization'].to_s, expected_token)

    head :unauthorized
  end
end
