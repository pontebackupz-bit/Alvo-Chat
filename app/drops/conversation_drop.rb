class ConversationDrop < BaseDrop
  include MessageFormatHelper

  def id
    @obj.try(:display_id)
  end

  def display_id
    @obj.try(:display_id)
  end

  def contact_name
    @obj.try(:contact)&.name.presence || 'Cliente'
  end

  def recent_messages
    @obj.try(:recent_messages).map do |message|
      {
        'sender' => message_sender_name(message),
        'incoming' => message.incoming?,
        'content' => render_message_content(transform_user_mention_content(message.content)),
        'attachments' => message.attachments.map(&:file_url)
      }
    end
  end

  def custom_attribute
    custom_attributes = @obj.try(:custom_attributes) || {}
    custom_attributes.transform_keys(&:to_s)
  end

  private

  def message_sender_name(message)
    sender = message.sender
    return message_without_sender_name(message) if sender.blank?
    return contact_name if sender.instance_of?(Contact)

    sender&.available_name || sender&.name
  end

  # Messages typed on the connected phone come back without an agent.
  def message_without_sender_name(message)
    return contact_name if message.incoming?
    return 'Enviada pelo celular' if message.content_attributes.to_h['external_echo']

    'Mensagem automática'
  end
end
