# Contacts shared in a chat: their WhatsApp picture, and "Conversar", which
# opens a conversation with that number on the same WhatsApp (reusing the one
# already open).
class OmnichannelCrm::ConversationStartsController < OmnichannelCrm::ApplicationController
  PICTURE_CACHE = 6.hours

  # The saved contact's picture or, for numbers not saved yet, WhatsApp's.
  def picture
    inbox = accessible_inboxes.find_by(id: params[:inbox_id])
    phone = params[:phone].to_s.gsub(/\D/, '')
    return render json: { url: nil } if inbox.nil? || phone.length < 8

    contact = current_account.contacts.find_by(phone_number: "+#{phone}")
    return render json: { url: contact.avatar_url } if contact&.avatar&.attached?

    render json: { url: whatsapp_picture(inbox, phone) }
  end

  def create
    inbox = accessible_inboxes.find_by(id: params[:inbox_id])
    return render json: { error: 'Você não tem acesso a esse número de WhatsApp.' }, status: :forbidden unless inbox

    phone = params[:phone].to_s.gsub(/\D/, '')
    return render json: { error: 'Telefone inválido.' }, status: :unprocessable_entity if phone.length < 8

    conversation = open_conversation(contact_inbox_for(inbox, phone))
    render json: { id: conversation.display_id }
  end

  private

  def whatsapp_picture(inbox, phone)
    return unless OmnichannelCrm::ConnectionsService.provider(inbox) == 'wppconnect'

    Rails.cache.fetch("omnichannel_crm/whatsapp_picture/#{inbox.id}/#{phone}", expires_in: PICTURE_CACHE) do
      OmnichannelCrm::WppconnectBridgeClient.new.profile_pic_url(OmnichannelCrm::ConnectionsService.session_id_for(inbox), phone) || ''
    end.presence
  rescue StandardError => e
    Rails.logger.info("WhatsApp picture of #{phone} not fetched: #{e.message}")
    nil
  end

  def accessible_inboxes
    administrator = Current.account_user&.administrator?
    administrator ? current_account.inboxes : current_user.assigned_inboxes.where(account_id: current_account.id)
  end

  def contact_inbox_for(inbox, phone)
    record = inbox.contact_inboxes.joins(:contact).find_by(contacts: { phone_number: "+#{phone}" }) ||
             inbox.contact_inboxes.find_by(source_id: phone) ||
             ContactInboxWithContactBuilder.new(source_id: phone, inbox: inbox,
                                                contact_attributes: { name: params[:name].presence || phone,
                                                                      phone_number: "+#{phone}" }).perform
    name_contact(record.contact)
    OmnichannelCrm::WhatsappAvatarJob.enqueue(record.contact, inbox, phone)
    record
  end

  # A contact still named after its number takes the name on the card.
  def name_contact(contact)
    return if params[:name].blank? || contact.name.to_s.match?(/[[:alpha:]]/)

    contact.update!(name: params[:name])
  end

  def open_conversation(contact_inbox)
    contact_inbox.conversations.where(status: %i[open pending]).order(:created_at).last ||
      ::Conversation.create!(account_id: current_account.id, inbox: contact_inbox.inbox, contact: contact_inbox.contact,
                             contact_inbox: contact_inbox, assignee: current_user,
                             team: current_account.teams.find_by(id: contact_inbox.inbox.channel.try(:additional_attributes).to_h['default_team_id']))
  end
end
