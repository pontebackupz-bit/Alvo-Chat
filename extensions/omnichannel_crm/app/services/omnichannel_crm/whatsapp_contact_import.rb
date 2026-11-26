# Brings the contacts saved on the phone of a number connected by QR code
# into AlvoChat, so the team can find them in Contatos and start a
# conversation from AlvoChat.
#
# Only people saved in the phone's address book are imported (no groups, no
# strangers who just wrote once). A contact already in AlvoChat keeps its name,
# unless that name is only the phone number: then it gets the saved name.
class OmnichannelCrm::WhatsappContactImport
  MIN_PHONE_DIGITS = 10
  MAX_PHONE_DIGITS = 15

  def initialize(inbox)
    @inbox = inbox
    @account = inbox.account
    @session_id = OmnichannelCrm::ConnectionsService.session_id_for(inbox)
    @stats = { 'created' => 0, 'updated' => 0, 'skipped' => 0 }
  end

  def perform
    progress!('running')
    saved_contacts.each { |entry| import(entry) }
    progress!('completed', 'finished_at' => Time.current.iso8601)
    @stats
  rescue StandardError => e
    Rails.logger.warn("WhatsApp contact import failed for inbox #{@inbox.id}: #{e.message}")
    progress!('failed', 'error' => e.message.truncate(200))
    raise
  end

  private

  def saved_contacts
    Array(OmnichannelCrm::WppconnectBridgeClient.new.contacts(@session_id)).select do |entry|
      entry.is_a?(Hash) && entry['isMyContact'] && !entry['isGroup'] && entry['isUser'] != false
    end
  end

  def import(entry)
    phone = phone_for(entry)
    name = name_for(entry)
    return @stats['skipped'] += 1 if phone.nil?

    contact = @account.contacts.find_by(phone_number: "+#{phone}")
    contact ? refresh(contact, name, phone) : create(name, phone)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    # One odd entry (e.g. the number already linked to another contact) does
    # not stop the rest.
    Rails.logger.info("WhatsApp contact skipped: #{e.message}")
    @stats['skipped'] += 1
  end

  # `5561999999999@c.us`; LID entries carry the number in `phoneNumber`.
  def phone_for(entry)
    id = entry['id'].is_a?(Hash) ? entry['id'] : {}
    raw = id['server'] == 'c.us' ? id['user'] : nil
    raw ||= jid_user(entry['phoneNumber'])
    digits = raw.to_s.gsub(/\D/, '')
    digits.length.between?(MIN_PHONE_DIGITS, MAX_PHONE_DIGITS) ? digits : nil
  end

  def jid_user(value)
    value = value['_serialized'] || value['user'] if value.is_a?(Hash)
    value.to_s.split('@').first
  end

  def name_for(entry)
    [entry['name'], entry['formattedName'], entry['pushname'], entry['shortName']]
      .map { |value| value.to_s.strip }
      .find { |value| value.present? && value.gsub(/[\s+()-]/, '') !~ /\A\d+\z/ }
  end

  def create(name, phone)
    ContactInboxWithContactBuilder.new(source_id: phone, inbox: @inbox,
                                       contact_attributes: { name: name || phone, phone_number: "+#{phone}" }).perform
    @stats['created'] += 1
  end

  def refresh(contact, name, phone)
    changed = false
    if name.present? && placeholder_name?(contact, phone)
      contact.update!(name: name)
      changed = true
    end
    unless @inbox.contact_inboxes.exists?(contact: contact)
      ContactInbox.create!(contact: contact, inbox: @inbox, source_id: phone)
      changed = true
    end
    @stats[changed ? 'updated' : 'skipped'] += 1
  end

  def placeholder_name?(contact, phone)
    digits = contact.name.to_s.gsub(/\D/, '')
    contact.name.blank? || digits == phone || contact.name.to_s.gsub(/[\s+()-]/, '') =~ /\A\d+\z/
  end

  def progress!(status, extra = {})
    attributes = @inbox.channel.reload.additional_attributes.to_h
    data = { 'status' => status, 'updated_at' => Time.current.iso8601 }.merge(@stats).merge(extra)
    @inbox.channel.update!(additional_attributes: attributes.merge('contacts_import' => data))
  end
end
