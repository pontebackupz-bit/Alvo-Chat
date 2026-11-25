# How received locations, polls and option lists are shown in AlvoChat (live
# and in the imported history), and how AlvoChat recognises the ones it sent.
module OmnichannelCrm::WhatsappRichText
  module_function

  def poll(message)
    options = Array(message['pollOptions']).filter_map { |option| option.is_a?(String) ? option : option['name'] }
    (["📊 *#{message['pollName'].to_s.strip.presence || 'Enquete'}*"] + options.map { |option| "▫️ #{option}" }).join("\n")
  end

  def list(message)
    list = message['list'].respond_to?(:[]) && !message['list'].is_a?(String) ? message['list'] : {}
    text = [list['title'], list['description']].filter_map { |part| part.to_s.strip.presence }.join("\n")
    button = list['buttonText'].to_s.strip.presence
    ["📋 #{text.presence || 'Lista de opções'}", button && "[#{button}]"].compact.join("\n")
  end

  def build_location(message, data)
    address = [data['loc'], data['address'], data['comment']].filter_map { |part| part.to_s.strip.presence }.first
    message.attachments.build(account_id: message.account_id, file_type: :location,
                              coordinates_lat: data['lat'].to_f, coordinates_long: data['lng'].to_f,
                              fallback_title: address || format('%<lat>.6f, %<lng>.6f', lat: data['lat'].to_f, lng: data['lng'].to_f))
  end

  def rich?(message)
    attributes = message.content_attributes.to_h
    attributes.key?('whatsapp_poll') || attributes.key?('whatsapp_list') ||
      message.attachments.any? { |attachment| %w[location contact].include?(attachment.file_type) }
  end
end
