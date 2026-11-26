class OmnichannelCrm::BaileysMessageDeliveryService
  def initialize(message)
    @message = message
  end

  def perform
    return unless deliverable?

    message.update!(
      source_id: send_messages.last.fetch('id'),
      status: :sent,
      content_attributes: message.content_attributes.except('external_error')
    )
  end

  private

  attr_reader :message

  def deliverable?
    # Private notes never leave AlvoChat.
    !message.private? && channel.is_a?(Channel::Api) && channel.additional_attributes['provider'] == 'baileys' &&
      (message.content.present? || message.attachments.present?) && message.source_id.blank?
  end

  def send_messages
    return [bridge.send_message(session_id, recipient, text, nil, **send_options)] if attachments.blank?

    attachments.map.with_index do |attachment, index|
      bridge.send_message(session_id, recipient, index.zero? ? caption(attachment) : '', attachment, **send_options)
    end
  end

  def send_options
    {}
  end

  # Replies from an agent start with the agent's name (see AgentSignature).
  def text
    OmnichannelCrm::AgentSignature.apply(body, OmnichannelCrm::AgentSignature.name_for(message))
  end

  # Voice notes have no caption on WhatsApp, so they go without the name.
  def caption(attachment)
    return body.to_s if attachment.file_type == 'audio' && body.blank?

    text
  end

  # WhatsApp has no rating widget: the CSAT survey asks for a 1-5 reply.
  def body
    content = OmnichannelCrm::WhatsappText.render(message.content)
    return content unless message.input_csat?

    [content, OmnichannelCrm::CsatReplyService::INSTRUCTIONS].compact_blank.join("\n\n")
  end

  def bridge
    @bridge ||= OmnichannelCrm::BaileysBridgeClient.new
  end

  def channel
    @channel ||= message.inbox.channel
  end

  def session_id
    channel.additional_attributes['session_id']
  end

  def attachments
    @attachments ||= message.attachments.select(&:with_attached_file?)
  end

  def recipient
    contact.phone_number.to_s.gsub(/\D/, '')
  end

  def contact
    @contact ||= message.conversation.contact
  end
end
