class OmnichannelCrm::WppconnectMessageDeliveryService < OmnichannelCrm::BaileysMessageDeliveryService
  private

  def deliverable?
    channel.is_a?(Channel::Api) && channel.additional_attributes['provider'] == 'wppconnect' &&
      (message.content.present? || message.attachments.present?) && message.source_id.blank?
  end

  def bridge
    @bridge ||= OmnichannelCrm::WppconnectBridgeClient.new
  end

  # Replies in a group conversation go to the group itself.
  def recipient
    return group_jid.delete_suffix(OmnichannelCrm::WhatsappGroup::SUFFIX) if group_jid

    super
  end

  def send_options
    { group: group_jid.present? }
  end

  def group_jid
    source_id = message.conversation.contact_inbox&.source_id
    OmnichannelCrm::WhatsappGroup.jid?(source_id) ? source_id : nil
  end
end
