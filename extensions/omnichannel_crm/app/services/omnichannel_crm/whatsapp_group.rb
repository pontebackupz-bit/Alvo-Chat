# WhatsApp groups as AlvoChat conversations: one contact per group (its
# `...@g.us` id is the source id), so the team reads and answers the group
# from the platform. Automations meant for one customer (chatbot, CSAT,
# leads) skip groups.
module OmnichannelCrm::WhatsappGroup
  SUFFIX = '@g.us'.freeze
  DEFAULT_NAME = 'Grupo do WhatsApp'.freeze

  module_function

  def jid?(jid)
    jid.to_s.end_with?(SUFFIX)
  end

  def conversation?(conversation)
    jid?(conversation&.contact_inbox&.source_id)
  end

  # Finds or creates the group's contact in the inbox and keeps its name.
  def contact_inbox_for(inbox, jid, name)
    record = inbox.contact_inboxes.find_by(source_id: jid)
    if record
      record.contact.update!(name: name) if name.present? && record.contact.name != name
      return record
    end

    ContactInboxWithContactBuilder.new(
      source_id: jid, inbox: inbox,
      contact_attributes: { name: name.presence || DEFAULT_NAME,
                            additional_attributes: { 'whatsapp_group' => true, 'whatsapp_group_id' => jid } }
    ).perform
  end

  # "**Maria:** text" so the team sees who wrote in the group.
  def with_author(content, author)
    return content if author.blank?

    content.present? ? "**#{author}:** #{content}" : "**#{author}:**"
  end
end
