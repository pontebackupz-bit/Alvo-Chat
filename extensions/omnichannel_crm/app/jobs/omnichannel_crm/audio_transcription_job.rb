# Transcribes a WhatsApp audio in the background as soon as it arrives.
class OmnichannelCrm::AudioTranscriptionJob < ApplicationJob
  queue_as :low

  def self.enqueue_for(message)
    return unless OmnichannelCrm::AudioTranscription.enabled?

    message.attachments.select { |attachment| attachment.file_type == 'audio' }.each { |attachment| perform_later(attachment.id) }
  end

  def perform(attachment_id)
    attachment = ::Attachment.find_by(id: attachment_id)
    OmnichannelCrm::AudioTranscription.new(attachment).perform if attachment
  rescue StandardError => e
    Rails.logger.info("Audio #{attachment_id} not transcribed: #{e.message}")
  end
end
