# Pages a conversation by when messages were sent, not by their database id.
#
# Messages imported from the WhatsApp history get new ids but their original,
# older dates. Chatwoot pages "messages before id X", so an imported message
# (high id, old date) was never reached when scrolling up. Comparing
# (created_at, id) keeps the order the list shows; for messages created live,
# date and id grow together, so nothing changes for them.
module OmnichannelCrm::MessageFinderChronology
  private

  def messages_before(before_id)
    reference = position(before_id)
    return super unless reference

    messages.reorder(created_at: :desc, id: :desc)
            .where('(messages.created_at, messages.id) < (?, ?)', reference.created_at, reference.id)
            .limit(20).reverse
  end

  def messages_after(after_id)
    reference = position(after_id)
    return super unless reference

    messages.reorder(created_at: :asc, id: :asc)
            .where('(messages.created_at, messages.id) > (?, ?)', reference.created_at, reference.id)
            .limit(100)
  end

  def messages_between(after_id, before_id)
    from = position(after_id)
    to = position(before_id)
    return super unless from && to

    messages.reorder(created_at: :asc, id: :asc)
            .where('(messages.created_at, messages.id) >= (?, ?)', from.created_at, from.id)
            .where('(messages.created_at, messages.id) < (?, ?)', to.created_at, to.id)
            .limit(1000)
  end

  def position(message_id)
    @conversation.messages.select(:id, :created_at).find_by(id: message_id)
  end
end
