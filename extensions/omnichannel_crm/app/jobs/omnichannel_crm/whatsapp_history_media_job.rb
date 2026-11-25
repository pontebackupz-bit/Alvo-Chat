require 'base64'
require 'stringio'

# Downloads the file of a message brought by the WhatsApp history import
# (photo, video, audio, document, sticker) and attaches it, replacing the
# "📷 Imagem" description. Media WhatsApp no longer has keeps the description.
# Files go one at a time: WhatsApp Web fails to decrypt parallel downloads.
class OmnichannelCrm::WhatsappHistoryMediaJob < ApplicationJob
  queue_as :low

  MAX_BYTES = OmnichannelCrm::BaileysMessagesController::MAX_MEDIA_BYTES
  # WhatsApp deletes old media from its servers (after about a month); it can
  # no longer be decrypted.
  EXPIRED = /Decrypt file error|Error trying to download/i

  # `items`: [[message_id, details], ...]; `details` has 'type', 'file_name',
  # 'mimetype' and 'content' (text kept once the file is attached, e.g. the
  # caption).
  def perform(items)
    items.each { |message_id, details| download(message_id, details.to_h) }
  end

  private

  def download(message_id, details)
    message = ::Message.find_by(id: message_id)
    return if message.nil? || message.source_id.blank? || message.attachments.exists?

    media = OmnichannelCrm::WppconnectBridgeClient.new.download_media(session_id(message), message.source_id)
    data = media['base64'].to_s.sub(%r{\Adata:[^;]+;base64,}, '')
    return if data.blank?

    bytes = Base64.decode64(data)
    return Rails.logger.info("History media #{message.source_id} skipped: over #{MAX_BYTES} bytes") if bytes.bytesize > MAX_BYTES

    attach(message, bytes, media['mimetype'].presence || details['mimetype'].presence || 'application/octet-stream', details)
  rescue StandardError => e
    Rails.logger.warn("History media for message #{message_id} not downloaded: #{e.message}")
    mark_unavailable(message) if e.message.match?(EXPIRED)
  end

  # Media WhatsApp no longer has: later imports do not try again.
  def mark_unavailable(message)
    message&.update_columns(content_attributes: message.content_attributes.to_h.merge('media_unavailable' => true))
  end

  def attach(message, bytes, mime_type, details)
    type = details['type'].to_s
    attachment = message.attachments.new(account_id: message.account_id, file_type: file_type(mime_type, type))
    attachment.meta = { is_voice_message: true } if type == 'ptt'
    OmnichannelCrm::WhatsappMedia.attach(attachment.file, bytes, filename: file_name(details, mime_type, type), mime: mime_type)
    attachment.save!
    message.update!(content: details['content'].presence, updated_at: Time.current)
    OmnichannelCrm::AudioTranscriptionJob.perform_later(attachment.id) if attachment.file_type == 'audio' && OmnichannelCrm::AudioTranscription.enabled?
  end

  def file_type(mime_type, type)
    return 'image' if type == 'sticker' || mime_type.start_with?('image/')
    return 'video' if mime_type.start_with?('video/')
    return 'audio' if mime_type.start_with?('audio/')

    'file'
  end

  def file_name(details, mime_type, type)
    details['file_name'].presence || "whatsapp-#{type.presence || 'arquivo'}.#{OmnichannelCrm::WhatsappMedia.extension(mime_type)}"
  end

  def session_id(message)
    message.inbox.channel.additional_attributes.to_h['session_id']
  end
end
