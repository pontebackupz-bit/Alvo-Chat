class OmnichannelCrm::BaileysMessageDeliveryJob < ApplicationJob
  queue_as :high

  MAX_FILE_AVAILABILITY_RETRIES = 4

  def perform(message_id, attempt = 0)
    message = Message.find(message_id)
    OmnichannelCrm::BaileysMessageDeliveryService.new(message).perform
  rescue ActiveStorage::FileNotFoundError => e
    return retry_after_upload(message_id, attempt) if attempt < MAX_FILE_AVAILABILITY_RETRIES

    mark_as_failed(message, e)
  rescue StandardError => e
    mark_as_failed(message, e)
  end

  private

  def retry_after_upload(message_id, attempt)
    self.class.set(wait: 2.seconds).perform_later(message_id, attempt + 1)
  end

  def mark_as_failed(message, error)
    return unless message

    message.update!(status: :failed, content_attributes: message.content_attributes.merge('external_error' => error.message))
  end
end
