# Brings the WhatsApp profile picture of a contact (person or group) into
# AlvoChat. Checked at most once a day per contact (once a week when it
# already has a picture), so busy chats do not ask WhatsApp on every message.
class OmnichannelCrm::WhatsappAvatarJob < ApplicationJob
  queue_as :low

  CHECKED_KEY = 'whatsapp_avatar_checked_at'.freeze

  def self.enqueue(contact, inbox, jid)
    return if contact.nil? || inbox.nil? || jid.blank? || OmnichannelCrm::ConnectionsService.provider(inbox) != 'wppconnect'
    return if recently_checked?(contact)

    attributes = contact.additional_attributes.to_h.merge(CHECKED_KEY => Time.current.iso8601)
    contact.update_columns(additional_attributes: attributes)
    perform_later(contact.id, inbox.id, jid)
  end

  def self.recently_checked?(contact)
    checked_at = Time.zone.parse(contact.additional_attributes.to_h[CHECKED_KEY].to_s)
    checked_at.present? && checked_at > (contact.avatar.attached? ? 7.days : 1.day).ago
  rescue ArgumentError
    false
  end

  def perform(contact_id, inbox_id, jid)
    contact = ::Contact.find_by(id: contact_id)
    inbox = ::Inbox.find_by(id: inbox_id)
    return if contact.nil? || inbox.nil?

    url = OmnichannelCrm::WppconnectBridgeClient.new.profile_pic_url(OmnichannelCrm::ConnectionsService.session_id_for(inbox), jid)
    Avatar::AvatarFromUrlJob.perform_now(contact, url) if url.present?
  rescue StandardError => e
    Rails.logger.info("WhatsApp picture for contact #{contact_id} not fetched: #{e.message}")
  end
end
