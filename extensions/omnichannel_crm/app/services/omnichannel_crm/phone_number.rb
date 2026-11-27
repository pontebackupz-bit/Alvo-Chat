# Normalizes phone numbers typed by people ("(11) 98765-4321", "011 98765 4321")
# to E.164 and lists the equivalent spellings of Brazilian mobiles, which
# WhatsApp sometimes reports without the ninth digit.
module OmnichannelCrm::PhoneNumber
  module_function

  def normalize(raw)
    text = raw.to_s.strip
    digits = text.gsub(/\D/, '')
    return if digits.blank?

    unless text.start_with?('+')
      digits = digits.sub(/\A0+/, '')
      digits = "55#{digits}" if digits.length.between?(10, 11)
    end
    "+#{digits}"
  end

  def variants(phone)
    digits = phone.to_s.delete('+')
    return [phone] unless digits.start_with?('55') && digits.length.between?(12, 13)

    area = digits[2, 2]
    local = digits[4..]
    alternate = if local.length == 9 && local.start_with?('9')
                  "+55#{area}#{local[1..]}"
                elsif local.length == 8 && local[0].to_i >= 6
                  "+55#{area}9#{local}"
                end
    [phone, alternate].compact
  end
end
