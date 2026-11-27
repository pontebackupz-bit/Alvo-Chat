class AgentNotifications::ConversationNotificationsMailer < ApplicationMailer
  def conversation_creation(conversation, agent, _user)
    return unless smtp_config_set_or_development?

    @agent = agent
    @conversation = conversation
    inbox_name = @conversation.inbox&.sanitized_name
    subject = "Nova conversa #{conversation_label} em #{inbox_name}"
    @action_url = app_account_conversation_url(account_id: @conversation.account_id, id: @conversation.display_id)
    send_mail_with_liquid(to: @agent.email, subject: subject) and return
  end

  def conversation_assignment(conversation, agent, _user)
    return unless smtp_config_set_or_development?

    @agent = agent
    @conversation = conversation
    subject = "#{@agent.available_name}, uma nova conversa foi atribuída a você: #{conversation_label}"
    @action_url = app_account_conversation_url(account_id: @conversation.account_id, id: @conversation.display_id)
    send_mail_with_liquid(to: @agent.email, subject: subject) and return
  end

  def conversation_mention(conversation, agent, message)
    return unless smtp_config_set_or_development?

    @agent = agent
    @conversation = conversation
    @message = message
    subject = "#{@agent.available_name}, você foi mencionado na conversa #{conversation_label}"
    @action_url = app_account_conversation_url(account_id: @conversation.account_id, id: @conversation.display_id)
    send_mail_with_liquid(to: @agent.email, subject: subject) and return
  end

  def assigned_conversation_new_message(conversation, agent, message)
    return unless smtp_config_set_or_development?
    # Don't spam with email notifications if agent is online
    return if ::OnlineStatusTracker.get_presence(message.account_id, 'User', agent.id)

    @agent = agent
    @conversation = conversation
    subject = "#{@agent.available_name}, nova mensagem na sua conversa #{conversation_label}"
    @action_url = app_account_conversation_url(account_id: @conversation.account_id, id: @conversation.display_id)
    send_mail_with_liquid(to: @agent.email, subject: subject) and return
  end

  def participating_conversation_new_message(conversation, agent, message)
    return unless smtp_config_set_or_development?
    # Don't spam with email notifications if agent is online
    return if ::OnlineStatusTracker.get_presence(message.account_id, 'User', agent.id)

    @agent = agent
    @conversation = conversation
    subject = "#{@agent.available_name}, nova mensagem na conversa #{conversation_label}"
    @action_url = app_account_conversation_url(account_id: @conversation.account_id, id: @conversation.display_id)
    send_mail_with_liquid(to: @agent.email, subject: subject) and return
  end

  private

  # "Maria Souza (#205)", or "#205" when the contact has no name.
  def conversation_label
    name = @conversation.contact&.name.presence
    name ? "#{name} (##{@conversation.display_id})" : "##{@conversation.display_id}"
  end

  def liquid_droppables
    super.merge({
                  user: @agent,
                  conversation: @conversation,
                  inbox: @conversation.inbox,
                  message: @message
                })
  end
end

AgentNotifications::ConversationNotificationsMailer.prepend_mod_with('AgentNotifications::ConversationNotificationsMailer')
