class OmnichannelCrm::ChatwootEventListener < BaseListener
  def contact_created(event)
    contact, account = extract_contact_and_account(event)
    publish('contact.created', account, contact_id: contact.id)
  end

  def conversation_created(event)
    conversation, account = extract_conversation_and_account(event)
    # Groups are read and answered by the team: no lead, chatbot or distribution.
    unless OmnichannelCrm::WhatsappGroup.conversation?(conversation)
      OmnichannelCrm::Lead.find_or_create_by!(account: account, contact: conversation.contact) do |lead|
        lead.conversation = conversation
        lead.owner = conversation.assignee
        lead.stage = :new_lead
      end
      # Chats brought in by "Importar histórico" are old: they are neither
      # handed to an agent nor greeted by the chatbot.
      unless conversation.additional_attributes.to_h['imported_from_whatsapp']
        OmnichannelCrm::DistributionService.new(conversation).perform
        OmnichannelCrm::WorkflowRunner.start_for(conversation)
      end
    end
    publish('conversation.created', account, conversation_id: conversation.id, contact_id: conversation.contact_id)
    publish('lead.created', account, conversation_id: conversation.id, contact_id: conversation.contact_id)
  end

  def message_created(event)
    message, account = extract_message_and_account(event)
    # Private notes are for the team only and never go to WhatsApp.
    if !message.private? && (message.outgoing? || OmnichannelCrm::CsatReplyService.bridge_survey?(message))
      OmnichannelCrm::BaileysMessageDeliveryJob.perform_later(message.id)
    end
    route_to_workflow_run(message)
    event_name = message.outgoing? ? 'message.sent' : 'message.received'
    publish(event_name, account, message_id: message.id, conversation_id: message.conversation_id, contact_id: message.sender_id)
  end

  def conversation_resolved(event)
    conversation, account = extract_conversation_and_account(event)
    OmnichannelCrm::WorkflowRun.finish_attendance_for(conversation)
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

  # A customer reply resumes a flow waiting for it; a person answering (in the
  # dashboard or from the phone) takes the conversation over from the flow.
  def route_to_workflow_run(message)
    if message.incoming?
      run = OmnichannelCrm::WorkflowRun.waiting_reply.find_by(conversation_id: message.conversation_id)
      OmnichannelCrm::WorkflowRunJob.perform_later(run.id, message.id) if run
    elsif message.outgoing? && (message.sender_type == 'User' || message.content_attributes['external_echo'].present?)
      OmnichannelCrm::WorkflowRun.cancel_for(message.conversation)
    end
  end

  def publish(event_name, account, payload)
    OmnichannelCrm::EventFanoutService.new(event_name: event_name, account: account, payload: payload).perform
  end
end
