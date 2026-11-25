# Brings the conversations already on the phone into AlvoChat: the most
# recent chats (people and groups) with their latest messages.
#
# History is written as it happened (original dates, sent/received) straight
# into the database, so it triggers no notification, chatbot, delivery or
# conversation reopening. Messages already in AlvoChat (same WhatsApp id) are
# skipped, so the import can run again safely. Media shows as a description
# until its file is downloaded in the background; shared contacts become
# contact cards.
class OmnichannelCrm::WhatsappHistoryImport
  SKIPPED_CHATS = /(status@broadcast|@newsletter|@broadcast)\z/
  MEDIA_LABELS = {
    'image' => '📷 Imagem', 'video' => '🎥 Vídeo', 'audio' => '🎵 Áudio', 'ptt' => '🎤 Mensagem de voz',
    'document' => '📄 Documento', 'sticker' => '💟 Figurinha', 'location' => '📍 Localização',
    'vcard' => '👤 Contato', 'multi_vcard' => '👥 Contatos'
  }.freeze
  TEXT_TYPES = %w[chat text].freeze
  # WhatsApp's own notices (encryption, security code, group events, ...):
  # not messages from anyone, so they are not imported.
  SYSTEM_TYPES = %w[notification_template e2e_notification gp2 notification protocol ciphertext broadcast_notification
                    pinned_message keep_in_chat reaction].freeze
  NOTICE_LABELS = { 'revoked' => '🚫 Mensagem apagada', 'call_log' => '📞 Chamada' }.freeze
  DOWNLOADABLE_TYPES = %w[image video audio ptt document sticker].freeze
  OFFLINE_MESSAGE = 'O número desta conversa está desconectado do WhatsApp. Conecte-o em Conexões e tente de novo.'.freeze
  NOT_FOUND_MESSAGE = 'O WhatsApp não encontrou o histórico deste contato no celular conectado. '                       'Confira se a conversa existe no aparelho e tente de novo.'.freeze

  # Raised when the number is not online, with a message for the team.
  class Offline < StandardError
    def initialize(msg = OFFLINE_MESSAGE)
      super
    end
  end

  def self.online?(inbox)
    OmnichannelCrm::ConnectionsService.session_state(inbox)[:status] == 'connected'
  rescue StandardError
    false
  end
  # WhatsApp Web's "all loaded messages" for a chat, then smaller fallbacks
  # for when loading everything fails.
  ALL_MESSAGES = -1
  MESSAGE_COUNTS = [ALL_MESSAGES, 1000, 200].freeze

  def initialize(inbox, chats: 100, messages_per_chat: 100)
    @inbox = inbox
    @chats = chats
    @messages_per_chat = messages_per_chat
    @session_id = inbox.channel.additional_attributes.to_h['session_id']
    @stats = { 'chats' => 0, 'messages' => 0 }
    @downloads = []
  end

  def perform
    raise Offline unless self.class.online?(@inbox)

    progress!('running')
    list_chats.each do |chat|
      import_chat(chat)
    rescue StandardError => e
      Rails.logger.warn("History import skipped chat #{chat_id(chat)} of inbox #{@inbox.id}: #{e.message}")
    end
    progress!('completed', 'finished_at' => Time.current.iso8601)
    download_files
    @stats
  rescue StandardError => e
    progress!('failed', 'error' => friendly(e))
    raise
  end

  # Every message WhatsApp has for this conversation's contact or group,
  # placed in this conversation. Progress is kept on the conversation.
  def import_conversation(conversation)
    jid = chat_jid_for(conversation.contact_inbox)
    raise ArgumentError, 'Este contato não tem um número de WhatsApp.' if jid.blank?

    raise Offline unless self.class.online?(conversation.inbox)

    conversation_progress!(conversation, 'running')
    fetch_avatar(conversation.contact_inbox, jid)
    messages = conversation_messages(jid)
    inserted = insert_messages(conversation, conversation.contact_inbox, messages, group: OmnichannelCrm::WhatsappGroup.jid?(jid))
    conversation_progress!(conversation, 'completed', 'messages' => inserted, 'finished_at' => Time.current.iso8601)
    download_files
    inserted
  rescue StandardError => e
    conversation_progress!(conversation, 'failed', 'error' => friendly(e))
    raise
  end

  # Older imports stored WhatsApp's notices as "📎 Arquivo": removes them and
  # names deleted messages and calls. Returns how many were fixed.
  def repair_notices(conversation)
    placeholders = conversation.messages.where(content: '📎 Arquivo').where.missing(:attachments)
                               .select { |message| message.content_attributes.to_h['imported_from_whatsapp'] }
    return 0 if placeholders.empty?

    types = bridge_messages(conversation).to_h { |message| [message_id(message), message] }
    placeholders.count { |message| repair_notice(message, types[message.source_id]) }
  end

  private

  def bridge_messages(conversation)
    jid = chat_jid_for(conversation.contact_inbox)
    return [] if jid.blank?

    chat_candidates(jid).each do |candidate|
      messages = bridge.chat_messages(@session_id, candidate, ALL_MESSAGES).select { |message| message.is_a?(Hash) }
      return messages if messages.any?
    rescue StandardError
      next
    end
    []
  end

  def repair_notice(message, original)
    type = original && original['type'].to_s
    return false if type.nil?
    return message.destroy! && true if SYSTEM_TYPES.include?(type)

    text = text_for(original)
    return false if text.blank? || text == message.content

    message.update_columns(content: text)
    true
  end

  # The first chat id and amount WhatsApp answers for. WPPConnect answers 401
  # ("Error on open list") when it cannot open the chat: a phone saved with or
  # without the Brazilian 9th digit, or a chat addressed by its `@lid`.
  def conversation_messages(jid)
    last_error = nil
    chat_candidates(jid).each do |candidate|
      MESSAGE_COUNTS.each do |count|
        messages = importable(bridge.chat_messages(@session_id, candidate, count))
        return messages if messages.any? || count != ALL_MESSAGES
      rescue StandardError => e
        Rails.logger.warn("History import for #{candidate} (count #{count}) on inbox #{@inbox.id} failed: #{e.message}")
        last_error = e
      end
    end
    raise last_error if last_error

    []
  end

  def chat_candidates(jid)
    return [jid] if OmnichannelCrm::WhatsappGroup.jid?(jid)

    digits = jid.split('@').first
    phones = [digits, *brazilian_variants(digits)]
    lids = phones.first(1).filter_map do |phone|
      bridge.lid_for(@session_id, phone)
    rescue StandardError
      nil
    end
    # Most chats are addressed by their LID now: try it first.
    (lids + phones.map { |phone| "#{phone}@c.us" }).uniq
  end

  # 55 + DDD + 9 + 8 digits <-> 55 + DDD + 8 digits.
  def brazilian_variants(digits)
    return [] unless digits.start_with?('55')
    return ["#{digits[0, 4]}#{digits[5..]}"] if digits.length == 13 && digits[4] == '9'
    return ["#{digits[0, 4]}9#{digits[4..]}"] if digits.length == 12

    []
  end

  # WhatsApp answers 404 "sessão não está ativa" when the number dropped and
  # 401 "Error on open list" when it could not open the chat.
  def friendly(error)
    return OFFLINE_MESSAGE if error.is_a?(Offline) || error.message.match?(/status 404|não está ativa|disconnected/i)
    return NOT_FOUND_MESSAGE if error.message.match?(/status 401|open list/i)

    error.message.truncate(300)
  end

  def chat_jid_for(contact_inbox)
    source_id = contact_inbox&.source_id.to_s
    return source_id if OmnichannelCrm::WhatsappGroup.jid?(source_id)

    digits = contact_inbox&.contact&.phone_number.to_s.gsub(/\D/, '').presence || source_id.gsub(/\D/, '').presence
    digits && "#{digits}@c.us"
  end

  def conversation_progress!(conversation, status, extra = {})
    data = { 'status' => status, 'updated_at' => Time.current.iso8601 }.merge(extra)
    conversation.update_columns(additional_attributes: conversation.additional_attributes.to_h.merge('whatsapp_history' => data))
  end

  def bridge
    @bridge ||= OmnichannelCrm::WppconnectBridgeClient.new
  end

  def list_chats
    bridge.list_chats(@session_id, @chats)
          .reject { |chat| chat_id(chat).blank? || chat_id(chat).match?(SKIPPED_CHATS) }
      .first(@chats)
  end

  def import_chat(chat)
    jid = chat_id(chat)
    messages = fetch_messages(jid)
    return if messages.empty?

    contact_inbox = contact_inbox_for(chat, jid)
    return unless contact_inbox

    conversation = contact_inbox.conversations.order(:created_at).last
    created = conversation.nil?
    conversation ||= new_conversation(contact_inbox)
    inserted = insert_messages(conversation, contact_inbox, messages, group: OmnichannelCrm::WhatsappGroup.jid?(jid))
    # A conversation made for the history is dated by its last message.
    conversation.update_columns(last_activity_at: conversation.messages.maximum(:created_at)) if created && inserted.positive?
    @stats['chats'] += 1 if inserted.positive?
    @stats['messages'] += inserted
    progress!('running')
  end

  def fetch_messages(jid)
    importable(bridge.chat_messages(@session_id, jid, @messages_per_chat))
  end

  def importable(messages)
    messages.select { |message| message.is_a?(Hash) && message_id(message) && SYSTEM_TYPES.exclude?(message['type'].to_s) }
  end

  def contact_inbox_for(chat, jid)
    if OmnichannelCrm::WhatsappGroup.jid?(jid)
      return OmnichannelCrm::WhatsappGroup.contact_inbox_for(@inbox, jid, chat_name(chat)).tap { |record| fetch_avatar(record, jid) }
    end

    phone = phone_for(jid)
    return if phone.blank?

    record = @inbox.contact_inboxes.joins(:contact).find_by(contacts: { phone_number: "+#{phone}" }) ||
             @inbox.contact_inboxes.find_by(source_id: phone) ||
             ContactInboxWithContactBuilder.new(source_id: phone, inbox: @inbox,
                                                contact_attributes: { name: chat_name(chat).presence || phone, phone_number: "+#{phone}" }).perform
    fetch_avatar(record, phone)
  end

  def fetch_avatar(contact_inbox, jid)
    OmnichannelCrm::WhatsappAvatarJob.enqueue(contact_inbox&.contact, @inbox, jid)
    contact_inbox
  end

  def phone_for(jid)
    return bridge.phone_number_for(@session_id, jid) if jid.end_with?('@lid')

    jid.split('@').first.gsub(/\D/, '').presence
  end

  # Imported history sits in a resolved conversation until the person writes
  # again; it never lands in the open queue by itself.
  def new_conversation(contact_inbox)
    ::Conversation.create!(account_id: @inbox.account_id, inbox: @inbox, contact: contact_inbox.contact,
                           contact_inbox: contact_inbox, status: :resolved,
                           additional_attributes: { 'imported_from_whatsapp' => true })
  end

  def insert_messages(conversation, contact_inbox, messages, group:)
    known = @inbox.messages.where(source_id: messages.map { |message| message_id(message) }).pluck(:source_id, :id).to_h
    now = Time.current
    rows = messages.filter_map do |message|
      next if known.key?(message_id(message))

      row(conversation, contact_inbox, message, group, now)
    end
    mark_revoked(messages, known)
    inserted = rows.empty? ? {} : ::Message.insert_all(rows, returning: %w[source_id id]).rows.to_h
    attach_files(messages, inserted.merge(without_files(known)), group)
    return 0 if rows.empty?

    latest = rows.pluck(:created_at).max
    conversation.update_columns(last_activity_at: latest) if conversation.last_activity_at.nil? || conversation.last_activity_at < latest
    rows.size
  end

  # Messages AlvoChat already has that were deleted on WhatsApp since: they
  # are kept and flagged. (Deleted ones AlvoChat never had have no content
  # left on WhatsApp and come as "🚫 Mensagem apagada".)
  def mark_revoked(messages, known)
    ids = messages.select { |message| message['type'].to_s == 'revoked' }.filter_map { |message| known[message_id(message)] }
    ::Message.where(id: ids).find_each { |message| OmnichannelCrm::WhatsappRevoke.mark(message) }
    mark_edited(messages, known)
  end

  # Messages AlvoChat has whose text was changed on WhatsApp since.
  def mark_edited(messages, known)
    edited = messages.select { |message| OmnichannelCrm::WhatsappEdit.edited_before_import?(message) && known[message_id(message)] }
    records = ::Message.where(id: edited.map { |message| known[message_id(message)] }).index_by(&:source_id)
    edited.each do |message|
      record = records[message_id(message)]
      OmnichannelCrm::WhatsappEdit.mark(record, message['body']) if record && TEXT_TYPES.include?(message['type'].to_s)
    end
  end

  # Imported earlier, when files were not brought: get them now.
  def without_files(known)
    return {} if known.empty?

    ::Message.where(id: known.values).where.missing(:attachments).select(:id, :source_id, :content_attributes)
             .select { |message| missing_file?(message.content_attributes.to_h) }
             .to_h { |message| [message.source_id, message.id] }
  end

  def missing_file?(attributes)
    attributes['imported_from_whatsapp'] && !attributes['media_unavailable']
  end

  # Contacts become cards right away; files download in the background.
  def attach_files(messages, ids, group)
    messages.each do |message|
      id = ids[message_id(message)]
      next unless id

      type = message['type'].to_s
      if OmnichannelCrm::WhatsappVcard.type?(type)
        attach_contacts(id, message)
      elsif type == 'location' && message['lat'].present?
        attach_location(id, message)
      elsif DOWNLOADABLE_TYPES.include?(type)
        @downloads << [id, media_details(message, type, group)]
      end
    end
  end

  # A single job for the whole import, so files download one at a time.
  def download_files
    OmnichannelCrm::WhatsappHistoryMediaJob.perform_later(@downloads) if @downloads.any?
    @downloads = []
  end

  def attach_contacts(id, message)
    texts = OmnichannelCrm::WhatsappVcard.texts_from(message)
    record = ::Message.find_by(id: id)
    return if texts.empty? || record.nil? || record.attachments.exists?

    OmnichannelCrm::WhatsappVcard.build_attachments(record, texts)
    # Groups keep only the "**Author:**" prefix.
    record.content = record.content.to_s[/\A\*\*[^*]+:\*\*/]
    record.save!
  end

  def attach_location(id, message)
    record = ::Message.find_by(id: id)
    return if record.nil? || record.attachments.exists?

    OmnichannelCrm::WhatsappRichText.build_location(record, message)
    record.content = record.content.to_s[/\A\*\*[^*]+:\*\*/]
    record.save!
  end

  def media_details(message, type, group)
    file_name = message['filename'].to_s.strip.presence
    caption = message['caption'].to_s.strip.presence
    caption = nil if caption == file_name
    caption = OmnichannelCrm::WhatsappGroup.with_author(caption.to_s, author_name(message)).presence if group && !from_me?(message)
    { 'type' => type, 'file_name' => file_name, 'mimetype' => message['mimetype'].to_s.presence, 'content' => caption }
  end

  def from_me?(message)
    ActiveModel::Type::Boolean.new.cast(message['fromMe'])
  end

  def row(conversation, contact_inbox, message, group, now)
    from_me = ActiveModel::Type::Boolean.new.cast(message['fromMe'])
    content = text_for(message)
    content = OmnichannelCrm::WhatsappGroup.with_author(content, author_name(message)) if group && !from_me
    {
      account_id: @inbox.account_id, inbox_id: @inbox.id, conversation_id: conversation.id,
      message_type: ::Message.message_types[from_me ? 'outgoing' : 'incoming'],
      content_type: ::Message.content_types['text'],
      status: ::Message.statuses[from_me ? 'delivered' : 'read'],
      sender_type: from_me ? nil : 'Contact', sender_id: from_me ? nil : contact_inbox.contact_id,
      content: content, source_id: message_id(message),
      content_attributes: { 'imported_from_whatsapp' => true, 'external_echo' => from_me || nil,
                            'whatsapp_edited' => OmnichannelCrm::WhatsappEdit.edited_before_import?(message) || nil }.compact,
      created_at: sent_at(message, now), updated_at: now
    }
  end

  def text_for(message)
    type = message['type'].to_s
    texts = OmnichannelCrm::WhatsappVcard.type?(type) ? OmnichannelCrm::WhatsappVcard.texts_from(message) : []
    return OmnichannelCrm::WhatsappVcard.summary(texts) if texts.any?
    caption = message['caption'].to_s.strip.presence
    return message['body'].to_s if TEXT_TYPES.include?(type) || type.blank?
    return NOTICE_LABELS[type] if NOTICE_LABELS.key?(type)
    return OmnichannelCrm::WhatsappRichText.poll(message) if type == 'poll_creation'
    return OmnichannelCrm::WhatsappRichText.list(message) if type == 'list'
    # Replies to lists and buttons, templates...: their text is the body.
    # (On media the body is a thumbnail, so it is not used.)
    return message['body'].to_s if !MEDIA_LABELS.key?(type) && message['body'].present?

    [MEDIA_LABELS.fetch(type, '📎 Arquivo'), caption].compact.join(': ')
  end

  def author_name(message)
    sender = message['sender'].is_a?(Hash) ? message['sender'] : {}
    [sender['pushname'], sender['name'], sender['formattedName'], message['notifyName']]
      .filter_map { |name| name.to_s.strip.presence }.first || message['author'].to_s.split('@').first
  end

  def sent_at(message, now)
    seconds = message['t'] || message['timestamp']
    seconds.present? ? Time.zone.at(seconds.to_i) : now
  end

  def message_id(message)
    id = message['id']
    id.is_a?(Hash) ? id['_serialized'] : id.presence
  end

  def chat_id(chat)
    id = chat['id']
    id.is_a?(Hash) ? id['_serialized'].to_s : id.to_s
  end

  def chat_name(chat)
    [chat['name'], chat.dig('contact', 'name'), chat.dig('contact', 'pushname'), chat['formattedTitle'],
     chat.dig('groupMetadata', 'subject')].filter_map { |name| name.to_s.strip.presence }.first
  end

  def progress!(status, extra = {})
    channel = @inbox.channel
    data = { 'status' => status, 'chats' => @stats['chats'], 'messages' => @stats['messages'],
             'updated_at' => Time.current.iso8601 }.merge(extra)
    channel.update_columns(additional_attributes: channel.additional_attributes.to_h.merge('history_import' => data))
  end
end
