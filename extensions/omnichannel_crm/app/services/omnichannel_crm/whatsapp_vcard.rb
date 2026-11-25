# Contacts shared on WhatsApp arrive as vCard text. They are stored as
# contact attachments (name + phone card with "add contact"), the same way
# WhatsApp Cloud contacts are, instead of the raw BEGIN:VCARD text.
module OmnichannelCrm::WhatsappVcard
  TYPES = %w[vcard multi_vcard].freeze

  module_function

  def type?(type)
    TYPES.include?(type.to_s)
  end

  # vCard texts of a WhatsApp message payload (WPPConnect / WA-JS).
  def texts_from(payload)
    list = payload['vcardList']
    texts = Array(list).filter_map { |item| item.is_a?(String) ? item : item['vcard'] }
    texts = [payload['body']] if texts.empty?
    texts.map(&:to_s).select { |text| text.include?('BEGIN:VCARD') }
  end

  # [{ name:, first_name:, last_name:, phones: [...] }] for each card.
  def parse(text)
    text.to_s.scan(/BEGIN:VCARD.*?END:VCARD/m).map { |card| parse_card(card) }
  end

  def parse_card(card)
    lines = unfold(card)
    full_name = value_of(lines, 'FN')
    last, first = value_of(lines, 'N').to_s.split(';')
    phones = lines.filter_map { |line| phone_from(line) }.uniq
    { name: full_name.presence || [first, last].compact_blank.join(' '), first_name: first.presence || full_name,
      last_name: last.presence, phones: phones }
  end

  # Builds one contact attachment per phone on the message (not saved).
  def build_attachments(message, texts)
    texts.flat_map { |text| parse(text) }.each do |card|
      phones = card[:phones].presence || ['Telefone não informado']
      phones.each do |phone|
        message.attachments.build(account_id: message.account_id, file_type: :contact, fallback_title: phone,
                                  meta: { firstName: card[:first_name], lastName: card[:last_name] }.compact)
      end
    end
  end

  # Text shown in previews and search: "👤 Name (+55 ...)".
  def summary(texts)
    texts.flat_map { |text| parse(text) }.map do |card|
      ['👤', card[:name].presence || 'Contato', card[:phones].first && "(#{card[:phones].first})"].compact.join(' ')
    end.join("\n")
  end

  # vCard folds long lines (e.g. PHOTO base64) with a leading space.
  def unfold(card)
    card.gsub(/\r?\n[ \t]/, '').split(/\r?\n/)
  end

  def value_of(lines, key)
    line = lines.find { |entry| entry.match?(/\A(?:item\d+\.)?#{key}[;:]/i) }
    line&.split(':', 2)&.last.to_s.strip.presence
  end

  def phone_from(line)
    return unless line.match?(/\A(?:item\d+\.)?TEL[;:]/i)

    waid = line[/waid=(\d+)/i, 1]
    return "+#{waid}" if waid

    number = line.split(':').last.to_s.strip
    digits = number.gsub(/[^\d+]/, '')
    digits.presence
  end
end
