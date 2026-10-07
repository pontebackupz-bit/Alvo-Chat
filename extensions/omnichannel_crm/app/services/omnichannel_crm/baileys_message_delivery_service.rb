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
    channel.is_a?(Channel::Api) && channel.additional_attributes['provider'] == 'baileys' &&
      (message.content.present? || message.attachments.present?) && message.source_id.blank?
  end

  def send_messages
    return [bridge.send_message(session_id, recipient, message.content)] if attachments.blank?

    attachments.map.with_index do |attachment, index|
      bridge.send_message(session_id, recipient, index.zero? ? message.content : '', attachment)
    end
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
