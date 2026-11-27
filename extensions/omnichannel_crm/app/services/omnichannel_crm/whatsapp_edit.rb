# A message edited on WhatsApp keeps its original text in AlvoChat; the panel
# shows below it that it was edited and the new text.
module OmnichannelCrm::WhatsappEdit
  module_function

  def mark(message, new_text)
    text = new_text.to_s.strip
    attributes = message.content_attributes.to_h
    return if text.blank? || text == message.content.to_s.strip || text == attributes['whatsapp_edited_text']

    message.update!(content_attributes: attributes.merge('whatsapp_edited' => true, 'whatsapp_edited_text' => text,
                                                         'whatsapp_edited_at' => Time.current.iso8601))
  end

  # Edited before reaching AlvoChat: WhatsApp only has the new text.
  def edited_before_import?(message)
    message['latestEditMsgKey'].present? || message['latestEditSenderTimestampMs'].present?
  end
end
