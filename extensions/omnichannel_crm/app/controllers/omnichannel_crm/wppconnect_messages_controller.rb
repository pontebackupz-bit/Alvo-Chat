class OmnichannelCrm::WppconnectMessagesController < OmnichannelCrm::BaileysMessagesController
  skip_before_action :authenticate_bridge!
  before_action :authenticate_wppconnect!

  def create
    return mark_revoked if params[:event] == 'onrevokedmessage'
    return mark_edited if params[:event] == 'onmessageedit'
    return head :accepted unless %w[onmessage onselfmessage].include?(params[:event])
    return head :accepted if phone_number.blank? && !group?
    return ignore_unavailable_media if media? && media_data.blank?
    return ignore_empty_event if !media? && !vcard? && !location? && content.blank?

    super
  end

  private

  # Deleted on WhatsApp ("apagar para todos"): the message stays in AlvoChat,
  # flagged so the panel shows that it was deleted.
  def mark_revoked
    ref = params[:refId]
    ref = ref[:_serialized] if ref.is_a?(ActionController::Parameters)
    message = ref.present? && inbox.messages.find_by(source_id: ref.to_s)
    OmnichannelCrm::WhatsappRevoke.mark(message) if message
    head :ok
  end

  # Edited on WhatsApp: the original text stays, the new one is shown below.
  def mark_edited
    edited = params[:msg].is_a?(ActionController::Parameters) ? params[:msg] : ActionController::Parameters.new
    ids = [params[:id], edited[:id]].map { |id| id.is_a?(ActionController::Parameters) ? id[:_serialized] : id }.compact_blank
    message = ids.lazy.filter_map { |id| inbox.messages.find_by(source_id: id.to_s) }.first
    OmnichannelCrm::WhatsappEdit.mark(message, edited[:body].presence || edited[:caption]) if message
    head :ok
  end

  def authenticate_wppconnect!
    expected_token = ENV.fetch('WPPCONNECT_WEBHOOK_TOKEN')
    return if ActiveSupport::SecurityUtils.secure_compare(params[:token].to_s, expected_token)

    head :unauthorized
  end

  def ignore_empty_event
    Rails.logger.info(
      "Ignoring empty WPPConnect event id=#{message_source_id.inspect} type=#{params[:type].inspect} session=#{session_id.inspect}"
    )
    head :accepted
  end

  def ignore_unavailable_media
    Rails.logger.warn(
      "Ignoring WPPConnect media without current payload id=#{message_source_id.inspect} type=#{params[:type].inspect} session=#{session_id.inspect}"
    )
    head :accepted
  end

  def contact_source_id
    @contact_source_id ||= phone_number
  end

  def inbox
    @inbox ||= Channel::Api.where("additional_attributes ->> 'session_id' = ?", session_id).first!.inbox.tap do |record|
      sync_inbox_phone_number(record)
    end
  end

  def contact_inbox
    return @contact_inbox ||= OmnichannelCrm::WhatsappGroup.contact_inbox_for(inbox, chat_jid, group_name) if group?

    # On messages sent from the phone the sender names are our own profile.
    super.tap { |record| sync_contact_name(record.contact) unless from_me? }
  end

  # Group messages: the conversation is the group, and each incoming message
  # names the participant who wrote it.
  def group?
    OmnichannelCrm::WhatsappGroup.jid?(chat_jid)
  end

  def group_name
    @group_name ||= [params.dig(:chat, :name), params.dig(:chat, :contact, :name), params[:groupName]]
                    .filter_map { |name| name.to_s.strip.presence }.first || bridge.chat_name(session_id, chat_jid)
  rescue StandardError => e
    Rails.logger.warn("Unable to fetch the WhatsApp group name: #{e.message}")
    @group_name = nil
  end

  def group_author
    names = [params.dig(:sender, :pushname), params.dig(:sender, :name), params.dig(:sender, :formattedName), params[:notifyName]]
    names.filter_map { |name| name.to_s.strip.presence }.first || jid_user(params[:author]).presence
  end

  def message_attributes
    attributes = super
    return attributes unless group? && !from_me?

    attributes.merge(
      content: OmnichannelCrm::WhatsappGroup.with_author(attributes[:content], group_author),
      content_attributes: attributes[:content_attributes].merge(group_author: { name: group_author, id: params[:author].to_s })
    )
  end

  def csat_reply?
    group? ? false : super
  end

  def conversation
    @conversation_record ||= super.tap do |record|
      created = record.previously_new_record?
      assign_default_team(record)
      assign_owner(record, created)
      fetch_avatar(record.contact)
    end
  end

  def fetch_avatar(contact)
    OmnichannelCrm::WhatsappAvatarJob.enqueue(contact, inbox, group? ? chat_jid : phone_number)
  rescue StandardError => e
    Rails.logger.info("WhatsApp picture not requested: #{e.message}")
  end

  # Numbers registered by a person in Conexões belong to them: their new
  # conversations go to that person, even if automatic assignment already
  # picked someone (groups stay with the team). Applied after the team, so
  # the team change does not drop them.
  def assign_owner(conversation, created)
    return if group? || (conversation.assignee_id.present? && !created)

    owner_id = inbox.channel.additional_attributes&.fetch('owner_id', nil)
    owner = owner_id && inbox.account.users.find_by(id: owner_id)
    conversation.update!(assignee: owner) if owner
  end

  def phone_number
    return @phone_number if defined?(@phone_number)

    return @phone_number = nil unless direct_message?

    @phone_number = lid? ? bridge.phone_number_for(session_id, chat_jid) : jid_user(chat_jid)
  rescue StandardError => e
    Rails.logger.warn("Unable to map WPPConnect LID to a phone number: #{e.message}")
    @phone_number = nil
  end

  def contact_inbox_with_phone_number
    super || migrate_lid_contact
  end

  def message_source_id
    raw_message_id = params[:id]
    @message_source_id ||= raw_message_id.is_a?(ActionController::Parameters) ? raw_message_id[:_serialized].presence : raw_message_id
  end

  def content
    return '' if vcard? || location?
    return params[:caption].presence || '' if media?
    return OmnichannelCrm::WhatsappRichText.poll(params) if params[:type].to_s == 'poll_creation'
    return OmnichannelCrm::WhatsappRichText.list(params) if params[:type].to_s == 'list'

    params[:body].presence || super
  end

  # Locations become a map card instead of the map thumbnail sent as body.
  def location?
    params[:type].to_s == 'location' && params[:lat].present? && params[:lng].present?
  end

  RICH_TYPES = %w[location vcard multi_vcard poll_creation list].freeze

  # The copy WhatsApp echoes of a location, contact, poll or list sent from
  # AlvoChat: its text differs from the stored one, so the usual match by
  # content does not see it.
  def pending_outgoing_message?
    return super unless from_me? && RICH_TYPES.include?(params[:type].to_s)

    Message.outgoing.where(conversation_id: contact_inbox.conversations.select(:id), sender_type: 'User', created_at: 2.minutes.ago..)
           .includes(:attachments).any? { |message| OmnichannelCrm::WhatsappRichText.rich?(message) }
  end

  # Shared contacts become contact cards instead of the raw vCard text.
  def vcard?
    OmnichannelCrm::WhatsappVcard.type?(params[:type]) && vcard_texts.any?
  end

  def vcard_texts
    @vcard_texts ||= OmnichannelCrm::WhatsappVcard.texts_from(params)
  end

  def attach_media(message)
    return OmnichannelCrm::WhatsappVcard.build_attachments(message, vcard_texts) if vcard?
    return OmnichannelCrm::WhatsappRichText.build_location(message, params) if location?

    super
  end

  def media_params
    return super unless media?

    @media_params ||= ActionController::Parameters.new(
      data: media_data,
      file_type: media_file_type,
      mime_type: mime_type,
      file_name: media_file_name,
      is_sticker: sticker_message?,
      is_animated_sticker: animated_sticker_message?,
      is_voice_message: params[:type].to_s == 'ptt'
    ).permit!
  end

  def from_me?
    ActiveModel::Type::Boolean.new.cast(params[:fromMe])
  end

  # The contact is the recipient on messages sent from the phone and the sender otherwise.
  def chat_jid
    jid = from_me? ? params[:to] : params[:from]
    jid.is_a?(ActionController::Parameters) ? jid[:_serialized].to_s : jid.to_s
  end

  def lid?
    chat_jid.end_with?('@lid')
  end

  def direct_message?
    lid? || chat_jid.end_with?('@c.us', '@s.whatsapp.net')
  end

  def bridge
    @bridge ||= OmnichannelCrm::WppconnectBridgeClient.new
  end

  def session_id
    params.require(:session)
  end

  def jid_user(jid)
    jid.to_s.split('@').first.gsub(/\D/, '').presence
  end

  def media?
    params[:isMedia] == true || params[:isMedia] == 'true' || webhook_mime_type.start_with?('image/', 'video/', 'audio/') ||
      %w[document sticker gif image video audio ptt].include?(params[:type].to_s)
  end

  def media_data
    return downloaded_media.fetch('base64') if from_me?

    params[:body].to_s.sub(%r{\Adata:[^;]+;base64,}, '')
  end

  def downloaded_media
    @downloaded_media ||= bridge.download_media(session_id, message_source_id)
  end

  def mime_type
    @mime_type ||= webhook_mime_type.presence ||
      (sticker_message? ? 'image/webp' : 'application/octet-stream')
  end

  def media_file_type
    return 'image' if sticker_message? || mime_type.start_with?('image/')
    return 'video' if mime_type.start_with?('video/')
    return 'audio' if mime_type.start_with?('audio/')

    'file'
  end

  def media_file_name
    return params[:filename] if params[:filename].present?

    "whatsapp-#{params[:type].presence || 'arquivo'}.#{OmnichannelCrm::WhatsappMedia.extension(mime_type)}"
  end

  def sticker_message?
    params[:type].to_s == 'sticker'
  end

  def animated_sticker_message?
    sticker_message? && ActiveModel::Type::Boolean.new.cast(params[:isAnimated])
  end

  def webhook_mime_type
    params[:mimetype].to_s
  end

  def migrate_lid_contact
    return unless lid?

    contact_inbox = inbox.contact_inboxes.find_by(source_id: jid_user(chat_jid))
    return unless contact_inbox

    attributes = { phone_number: "+#{phone_number}" }
    attributes[:name] = phone_number if contact_inbox.contact.name == jid_user(chat_jid)
    contact_inbox.contact.update!(attributes)
    contact_inbox.update!(source_id: phone_number)
    contact_inbox
  end

  def sync_inbox_phone_number(record)
    attributes = record.channel.additional_attributes || {}
    return if attributes['phone_number'].present?

    connected_phone_number = bridge.connected_phone_number(session_id)
    return if connected_phone_number.blank?

    record.channel.update!(additional_attributes: attributes.merge('phone_number' => connected_phone_number))
  rescue StandardError => e
    Rails.logger.warn("Unable to fetch the WPPConnect session phone number: #{e.message}")
  end

  def sync_contact_name(contact)
    name = wppconnect_contact_name
    return if name.blank? || !generated_contact_name?(contact.name)

    contact.update!(name: name)
  rescue StandardError => e
    Rails.logger.warn("Unable to fetch the WPPConnect contact name: #{e.message}")
  end

  def wppconnect_contact_name
    return @wppconnect_contact_name if defined?(@wppconnect_contact_name)

    names = [
      params[:notifyName],
      params.dig(:sender, :pushname),
      params.dig(:sender, :verifiedName),
      params.dig(:sender, :name),
      params.dig(:sender, :formattedName)
    ].filter_map { |name| name.to_s.strip.presence }

    @wppconnect_contact_name = names.find { |name| name.gsub(/\D/, '') != phone_number }
  end

  def generated_contact_name?(name)
    name.to_s.gsub(/\D/, '') == phone_number
  end

  def assign_default_team(conversation)
    return if conversation.team_id.present?

    team_id = inbox.channel.additional_attributes&.fetch('default_team_id', nil)
    team = inbox.account.teams.find_by(id: team_id)
    conversation.update!(team: team) if team
  end
end
