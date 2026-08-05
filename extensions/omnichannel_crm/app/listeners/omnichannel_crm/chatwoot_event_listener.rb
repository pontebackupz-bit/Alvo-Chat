class OmnichannelCrm::ChatwootEventListener < BaseListener
  def contact_created(event)
    contact, account = extract_contact_and_account(event)
    publish('contact.created', account, contact_id: contact.id)
  end

  def conversation_created(event)
    conversation, account = extract_conversation_and_account(event)
    OmnichannelCrm::Lead.find_or_create_by!(account: account, contact: conversation.contact) do |lead|
      lead.conversation = conversation
      lead.owner = conversation.assignee
      lead.stage = :new_lead
    end
    OmnichannelCrm::DistributionService.new(conversation).perform
    publish('conversation.created', account, conversation_id: conversation.id, contact_id: conversation.contact_id)
    publish('lead.created', account, conversation_id: conversation.id, contact_id: conversation.contact_id)
  end

  def message_created(event)
    message, account = extract_message_and_account(event)
    OmnichannelCrm::BaileysMessageDeliveryJob.perform_later(message.id) if message.outgoing?
    event_name = message.outgoing? ? 'message.sent' : 'message.received'
    publish(event_name, account, message_id: message.id, conversation_id: message.conversation_id, contact_id: message.sender_id)
  end

  def conversation_resolved(event)
    conversation, account = extract_conversation_and_account(event)
    publish('conversation.resolved', account, conversation_id: conversation.id, contact_id: conversation.contact_id)
  end

  def assignee_changed(event)
    conversation, account = extract_conversation_and_account(event)
    publish('assignee.changed', account, conversation_id: conversation.id, assignee_id: conversation.assignee_id)
  end

  def conversation_status_changed(event)
    conversation, account = extract_conversation_and_account(event)
    publish('conversation.status_changed', account, conversation_id: conversation.id, status: conversation.status)
  end

  private

  def publish(event_name, account, payload)
    OmnichannelCrm::EventFanoutService.new(event_name: event_name, account: account, payload: payload).perform
  end
end
