# Whoever answers first takes the chat: the first reply an agent sends in a
# conversation with no one assigned makes it theirs ("Fulano se atribuiu").
# Not for private notes, automatic messages, replies sent from the phone
# (AlvoChat does not know who wrote them), administrators or groups, which
# stay with the team.
module OmnichannelCrm::FirstReplyAssignment
  module_function

  def perform(message)
    return unless eligible?(message)

    conversation = message.conversation
    # The user stays set until after the commit, when the activity message
    # is written.
    as_user(message.sender) do
      conversation.with_lock do
        # Two agents answering at the same time: the first one keeps it.
        next if conversation.assignee_id.present?

        conversation.update!(assignee: message.sender)
      end
    end
  end

  def eligible?(message)
    message.outgoing? && !message.private? && message.sender_type == 'User' && message.sender.present? &&
      message.conversation.assignee_id.nil? && !OmnichannelCrm::WhatsappGroup.conversation?(message.conversation) &&
      !OmnichannelCrm::AdministratorsNotAutoAssigned.administrator?(message.sender, message.account_id)
  end

  # The activity message reads "Fulano se atribuiu" when the change is made
  # by the assignee themselves.
  def as_user(user)
    previous = Current.user
    Current.user = user
    yield
  ensure
    Current.user = previous
  end
end
