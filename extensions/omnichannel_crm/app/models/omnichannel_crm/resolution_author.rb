# Who resolved a conversation. The status activity message ("Conversa foi
# marcada como resolvida por …") is the record of each resolution: from now
# on it also keeps the id of the person who clicked "Resolver", so the
# Painel comercial credits the resolution to them and not to whoever the
# conversation happens to be assigned to. Older messages only have the name
# in the text, which `user_id_for` matches against the account's users.
module OmnichannelCrm::ResolutionAuthor
  TEMPLATE_KEY = 'conversations.activity.status.resolved'.freeze

  # Prepended on Conversation.
  module Activity
    private

    def activity_message_params(content, content_attributes: nil)
      activity = content_attributes&.dig(:activity)
      if activity && activity[:type] == 'conversation_status_changed' && resolved? && Current.user && Current.executed_by.blank?
        content_attributes = content_attributes.merge(activity: activity.merge(user_id: Current.user.id))
      end
      super
    end
  end

  module_function

  def sql
    OmnichannelCrm::MessageAttributesSql
  end

  # Resolution activity messages of the given conversations.
  def messages(conversations)
    ::Message.activity.where(conversation_id: conversations.select(:id))
             .where("#{sql.field('activity', 'status')} = 'resolved' OR " \
                    "(#{sql.field('activity', 'type')} IS NULL AND (#{legacy_content_sql}))")
  end

  # { user_id => resolutions } for the messages, read from the stored id or,
  # for older messages, from the name in the text.
  def counts(messages, users)
    by_text = users.each_with_object({}) do |(id, name), map|
      texts_for(name).each { |text| map[text] = id }
    end
    messages.pluck(Arel.sql(sql.field('activity', 'user_id')), :content)
            .each_with_object(Hash.new(0)) do |(stored_id, content), counts|
      id = stored_id.presence&.to_i || by_text[content.to_s]
      counts[id] += 1 if id
    end
  end

  def texts_for(name)
    I18n.available_locales.filter_map { |locale| I18n.t(TEMPLATE_KEY, locale: locale, user_name: name, default: nil) }.uniq
  end

  # Activity messages saved before the status was kept in content_attributes.
  def legacy_content_sql
    prefixes = I18n.available_locales.filter_map do |locale|
      I18n.t(TEMPLATE_KEY, locale: locale, user_name: '%{user_name}', default: nil)&.split('%{user_name}')&.first
    end.uniq.compact_blank
    return 'FALSE' if prefixes.empty?

    prefixes.map { |prefix| ::Message.sanitize_sql_array(['messages.content LIKE ?', "#{::Message.sanitize_sql_like(prefix)}%"]) }.join(' OR ')
  end
end
