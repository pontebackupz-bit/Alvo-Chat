# Brings the WhatsApp profile picture of a contact (person or group) into
# AlvoChat. Checked at most once a day per contact (once a week when it
# already has a picture), so busy chats do not ask WhatsApp on every message.
#
# A contact only counts as checked once WhatsApp answered (with a picture or
# with none). When the number is offline or reconnecting (e.g. right after a
# deploy) the check fails and is tried again after RETRY_AFTER.
class OmnichannelCrm::WhatsappAvatarJob < ApplicationJob
  queue_as :low

  CHECKED_KEY = 'whatsapp_avatar_checked_at'.freeze
  QUEUED_KEY = 'whatsapp_avatar_queued_at'.freeze
  RETRY_AFTER = 10.minutes

  def self.enqueue(contact, inbox, jid, force: false)
    return false if contact.nil? || inbox.nil? || jid.blank? || OmnichannelCrm::ConnectionsService.provider(inbox) != 'wppconnect'
    return false if !force && (recently_checked?(contact) || recently_queued?(contact))

    stamp(contact, QUEUED_KEY => Time.current.iso8601)
    perform_later(contact.id, inbox.id, jid)
    true
  end

  def self.recently_checked?(contact)
    checked_at = time(contact, CHECKED_KEY)
    checked_at.present? && checked_at > (contact.avatar.attached? ? 7.days : 1.day).ago
  end

  def self.recently_queued?(contact)
    queued_at = time(contact, QUEUED_KEY)
    queued_at.present? && queued_at > RETRY_AFTER.ago
  end

  def self.time(contact, key)
    Time.zone.parse(contact.additional_attributes.to_h[key].to_s)
  rescue ArgumentError
    nil
  end

  def self.stamp(contact, values)
    contact.update_columns(additional_attributes: contact.additional_attributes.to_h.merge(values))
  end

  def perform(contact_id, inbox_id, jid)
    contact = ::Contact.find_by(id: contact_id)
    inbox = ::Inbox.find_by(id: inbox_id)
    return if contact.nil? || inbox.nil?

    url = OmnichannelCrm::WppconnectBridgeClient.new.profile_pic_url(OmnichannelCrm::ConnectionsService.session_id_for(inbox), jid)
    download(contact, url) if url.present?
    # Checked when WhatsApp has no picture or it was saved; a failed download
    # is tried again later.
    self.class.stamp(contact.reload, CHECKED_KEY => Time.current.iso8601) if url.blank? || contact.avatar.attached?
  rescue StandardError => e
    Rails.logger.info("WhatsApp picture for contact #{contact_id} not fetched, will retry: #{e.message}")
  end

  private

  # Avatar::AvatarFromUrlJob skips an address it already tried (same hash) or
  # one synced in the last minute, even when that download failed. A contact
  # still without a picture gets those marks cleared first.
  def download(contact, url)
    self.class.stamp(contact, 'avatar_url_hash' => nil, 'last_avatar_sync_at' => nil) unless contact.avatar.attached?
    Avatar::AvatarFromUrlJob.perform_now(contact.reload, url)
  end
end
