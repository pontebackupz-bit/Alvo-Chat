namespace :omnichannel_crm do
  desc 'Install default CRM permissions and roles for ACCOUNT_ID'
  task seed_roles: :environment do
    account_id = ENV.fetch('ACCOUNT_ID')
    OmnichannelCrm::RoleDefaults.install_permissions!
    OmnichannelCrm::RoleDefaults.install(Account.find(account_id))
  end

  desc 'Bring the WhatsApp profile pictures of contacts that have none'
  task whatsapp_avatars: :environment do
    queued = 0
    Inbox.where(channel_type: 'Channel::Api').find_each do |inbox|
      next unless OmnichannelCrm::ConnectionsService.provider(inbox) == 'wppconnect'

      inbox.contact_inboxes.includes(contact: { avatar_attachment: :blob }).find_each do |contact_inbox|
        contact = contact_inbox.contact
        next if contact.nil? || contact.avatar.attached?

        source = contact_inbox.source_id.to_s
        jid = OmnichannelCrm::WhatsappGroup.jid?(source) ? source : contact.phone_number.to_s.gsub(/\D/, '').presence
        next unless jid

        before = contact.additional_attributes.to_h['whatsapp_avatar_checked_at']
        OmnichannelCrm::WhatsappAvatarJob.enqueue(contact, inbox, jid)
        queued += 1 if contact.additional_attributes.to_h['whatsapp_avatar_checked_at'] != before
      end
    end
    puts "#{queued} foto(s) de perfil solicitada(s) ao WhatsApp."
  end

  desc 'Repair WhatsApp media saved before: playable audio and notices shown as files'
  task repair_whatsapp_media: :environment do
    audios = ActiveStorage::Blob.where(content_type: OmnichannelCrm::WhatsappMedia::ALIASES.keys)
    audio_count = audios.count
    audios.find_each do |blob|
      filename = blob.filename.to_s.include?('codecs') ? blob.filename.to_s.sub(/\.ogg.*\z/, '.ogg') : blob.filename.to_s
      blob.update_columns(content_type: OmnichannelCrm::WhatsappMedia.content_type(blob.content_type), filename: filename)
    end
    puts "#{audio_count} áudio(s) corrigido(s)."

    fixed = 0
    conversation_ids = Message.where(content: '📎 Arquivo').where.missing(:attachments).reorder(nil).distinct.pluck(:conversation_id)
    Conversation.where(id: conversation_ids).includes(:inbox).find_each do |conversation|
      next unless OmnichannelCrm::ConnectionsService.provider(conversation.inbox) == 'wppconnect'
      next unless OmnichannelCrm::WhatsappHistoryImport.online?(conversation.inbox)

      fixed += OmnichannelCrm::WhatsappHistoryImport.new(conversation.inbox).repair_notices(conversation)
    rescue StandardError => e
      puts "Conversa #{conversation.display_id}: #{e.message}"
    end
    puts "#{fixed} aviso(s) do WhatsApp corrigido(s)."
  end

  desc 'Turn WhatsApp contacts received as raw vCard text into contact cards'
  task convert_vcards: :environment do
    converted = 0
    Message.where('content LIKE ?', '%BEGIN:VCARD%').where.missing(:attachments).find_each do |message|
      texts = [message.content.to_s[/\A(\*\*[^*]+:\*\* )?(.*)\z/m, 2]]
      next if OmnichannelCrm::WhatsappVcard.parse(texts.first).empty?

      OmnichannelCrm::WhatsappVcard.build_attachments(message, texts)
      message.content = message.content.to_s[/\A\*\*[^*]+:\*\*/]
      message.save!
      converted += 1
    end
    puts "#{converted} contato(s) convertido(s)."
  end
end
