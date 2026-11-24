# Brings the conversations already on the phone into AlvoChat: the most
# recent chats (people and groups) with their latest messages.
#
# History is written as it happened (original dates, sent/received) straight
# into the database, so it triggers no notification, chatbot, delivery or
# conversation reopening. Messages already in AlvoChat (same WhatsApp id) are
# skipped, so the import can run again safely. Media shows as a description;
# the files themselves are not downloaded.
class OmnichannelCrm::WhatsappHistoryImport
  SKIPPED_CHATS = /(status@broadcast|@newsletter|@broadcast)\z/
  MEDIA_LABELS = {
    'image' => '📷 Imagem', 'video' => '🎥 Vídeo', 'audio' => '🎵 Áudio', 'ptt' => '🎤 Mensagem de voz',
    'document' => '📄 Documento', 'sticker' => '💟 Figurinha', 'location' => '📍 Localização',
    'vcard' => '👤 Contato', 'multi_vcard' => '👥 Contatos'
  }.freeze
  TEXT_TYPES = %w[chat text].freeze
  OFFLINE_MESSAGE = 'O número desta conversa está desconectado do WhatsApp. Conecte-o em Conexões e tente de novo.'.freeze

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
  # WhatsApp Web's "all loaded messages" for a chat.
  ALL_MESSAGES = -1

  def initialize(inbox, chats: 100, messages_per_chat: 100)
    @inbox = inbox
    @chats = chats
    @messages_per_chat = messages_per_chat
    @session_id = inbox.channel.additional_attributes.to_h['session_id']
    @stats = { 'chats' => 0, 'messages' => 0 }
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
    messages = bridge.chat_messages(@session_id, jid, ALL_MESSAGES).select { |message| message.is_a?(Hash) && message_id(message) }
    inserted = insert_messages(conversation, conversation.contact_inbox, messages, group: OmnichannelCrm::WhatsappGroup.jid?(jid))
    conversation_progress!(conversation, 'completed', 'messages' => inserted, 'finished_at' => Time.current.iso8601)
    inserted
  rescue StandardError => e
    conversation_progress!(conversation, 'failed', 'error' => friendly(e))
    raise
  end

  private

  # WhatsApp answers 404 "sessão não está ativa" when the number dropped.
  def friendly(error)
    return OFFLINE_MESSAGE if error.is_a?(Offline) || error.message.match?(/status 404|não está ativa|disconnected/i)

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
    bridge.chat_messages(@session_id, jid, @messages_per_chat).select { |message| message.is_a?(Hash) && message_id(message) }
  end

  def contact_inbox_for(chat, jid)
    return OmnichannelCrm::WhatsappGroup.contact_inbox_for(@inbox, jid, chat_name(chat)) if OmnichannelCrm::WhatsappGroup.jid?(jid)

    phone = phone_for(jid)
    return if phone.blank?

    @inbox.contact_inboxes.joins(:contact).find_by(contacts: { phone_number: "+#{phone}" }) ||
      @inbox.contact_inboxes.find_by(source_id: phone) ||
      ContactInboxWithContactBuilder.new(source_id: phone, inbox: @inbox,
                                         contact_attributes: { name: chat_name(chat).presence || phone, phone_number: "+#{phone}" }).perform
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
    known = @inbox.messages.where(source_id: messages.map { |message| message_id(message) }).pluck(:source_id).to_set
    now = Time.current
    rows = messages.filter_map do |message|
      next if known.include?(message_id(message))

      row(conversation, contact_inbox, message, group, now)
    end
    return 0 if rows.empty?

    ::Message.insert_all(rows)
    latest = rows.pluck(:created_at).max
    conversation.update_columns(last_activity_at: latest) if conversation.last_activity_at.nil? || conversation.last_activity_at < latest
    rows.size
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
      content_attributes: { 'imported_from_whatsapp' => true, 'external_echo' => from_me || nil }.compact,
      created_at: sent_at(message, now), updated_at: now
    }
  end

  def text_for(message)
    type = message['type'].to_s
    caption = message['caption'].to_s.strip.presence
    return message['body'].to_s if TEXT_TYPES.include?(type) || type.blank?

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
