class OmnichannelCrm::BaileysMessageDeliveryJob < ApplicationJob
  queue_as :high

  MAX_FILE_AVAILABILITY_RETRIES = 4
  MAX_WPPCONNECT_RECONNECT_RETRIES = 20

  def perform(message_id, file_attempt = 0, reconnect_attempt = 0)
    message = Message.find(message_id)
    return unless message.outgoing?

    delivery_service(message).perform
  rescue OmnichannelCrm::WppconnectBridgeClient::SessionUnavailable => e
    return retry_after_wppconnect_reconnect(message_id, file_attempt, reconnect_attempt, e) if reconnect_attempt < MAX_WPPCONNECT_RECONNECT_RETRIES

    mark_as_failed(message, e)
  rescue ActiveStorage::FileNotFoundError => e
    return retry_after_upload(message_id, file_attempt, reconnect_attempt) if file_attempt < MAX_FILE_AVAILABILITY_RETRIES

    mark_as_failed(message, e)
  rescue StandardError => e
    mark_as_failed(message, e)
  end

  private

  def delivery_service(message)
    return OmnichannelCrm::WppconnectMessageDeliveryService.new(message) if message.inbox.channel.additional_attributes['provider'] == 'wppconnect'

    OmnichannelCrm::BaileysMessageDeliveryService.new(message)
  end

  def retry_after_upload(message_id, file_attempt, reconnect_attempt)
    self.class.set(wait: 2.seconds).perform_later(message_id, file_attempt + 1, reconnect_attempt)
  end

  def retry_after_wppconnect_reconnect(message_id, file_attempt, reconnect_attempt, error)
    wait = [5 * (reconnect_attempt + 1), 30].min.seconds
    Rails.logger.warn("Deferring WPPConnect delivery message_id=#{message_id} for #{wait.to_i}s: #{error.message}")
    self.class.set(wait: wait).perform_later(message_id, file_attempt, reconnect_attempt + 1)
  end

  def mark_as_failed(message, error)
    return unless message

    message.update!(status: :failed, content_attributes: message.content_attributes.merge('external_error' => error.message))
  end
end
