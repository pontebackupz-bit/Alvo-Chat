class OmnichannelCrm::WppconnectMessageDeliveryService < OmnichannelCrm::BaileysMessageDeliveryService
  private

  def deliverable?
    # Private notes never leave AlvoChat.
    !message.private? && channel.is_a?(Channel::Api) && channel.additional_attributes['provider'] == 'wppconnect' &&
      (message.content.present? || message.attachments.present?) && message.source_id.blank?
  end

  def bridge
    @bridge ||= OmnichannelCrm::WppconnectBridgeClient.new
  end

  # Location, contact, poll and option list go through their own WhatsApp
  # routes (see OmnichannelCrm::WhatsappRichMessage).
  def send_messages
    rich = rich_message
    return super unless rich

    [rich]
  end

  def rich_message
    options = send_options
    location = message.attachments.find { |attachment| attachment.file_type == 'location' }
    contact = message.attachments.find { |attachment| attachment.file_type == 'contact' }
    poll = message.content_attributes.to_h['whatsapp_poll']
    list = message.content_attributes.to_h['whatsapp_list']

    if location
      bridge.send_location(session_id, recipient, lat: location.coordinates_lat, lng: location.coordinates_long,
                                                  title: location.meta.to_h['name'], address: location.fallback_title, **options)
    elsif contact
      bridge.send_contact(session_id, recipient, phone: contact.fallback_title.to_s.gsub(/\D/, ''),
                                                 name: contact.meta.to_h.values_at('firstName', 'lastName').compact_blank.join(' '), **options)
    elsif poll
      bridge.send_poll(session_id, recipient, name: poll['name'], choices: poll['options'],
                                              selectable_count: poll['selectable_count'].to_i, **options)
    elsif list
      bridge.send_list(session_id, recipient, description: list['description'], button_text: list['button_text'],
                                              sections: list['sections'], **options)
    end
  end

  # Replies in a group conversation go to the group itself.
  def recipient
    return group_jid.delete_suffix(OmnichannelCrm::WhatsappGroup::SUFFIX) if group_jid

    super
  end

  def send_options
    { group: group_jid.present? }
  end

  def group_jid
    source_id = message.conversation.contact_inbox&.source_id
    OmnichannelCrm::WhatsappGroup.jid?(source_id) ? source_id : nil
  end
end
