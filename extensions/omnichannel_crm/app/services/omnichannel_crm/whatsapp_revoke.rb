# A message deleted on WhatsApp keeps its content in AlvoChat; the panel shows
# below it that it was deleted. (`deleted` is Chatwoot's own flag, which hides
# the content, so a separate one is used.)
module OmnichannelCrm::WhatsappRevoke
  module_function

  def mark(message)
    return if message.content_attributes.to_h['whatsapp_revoked']

    attributes = message.content_attributes.to_h.merge('whatsapp_revoked' => true, 'whatsapp_revoked_at' => Time.current.iso8601)
    message.update!(content_attributes: attributes)
  end
end
