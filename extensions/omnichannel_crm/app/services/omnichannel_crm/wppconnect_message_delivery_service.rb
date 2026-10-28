class OmnichannelCrm::WppconnectMessageDeliveryService < OmnichannelCrm::BaileysMessageDeliveryService
  private

  def deliverable?
    channel.is_a?(Channel::Api) && channel.additional_attributes['provider'] == 'wppconnect' &&
      (message.content.present? || message.attachments.present?) && message.source_id.blank?
  end

  def bridge
    @bridge ||= OmnichannelCrm::WppconnectBridgeClient.new
  end
end
