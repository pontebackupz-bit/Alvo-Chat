# Location, contact card, poll and option list sent from the reply box to a
# WhatsApp connected by QR code. The message is created like any reply (same
# author, conversation and delivery job); the delivery service sends it
# through the matching WhatsApp route.
class OmnichannelCrm::WhatsappRichMessage
  class Invalid < StandardError; end

  KINDS = %w[location contact poll list].freeze
  MAX_POLL_OPTIONS = 12
  MAX_LIST_ROWS = 10

  def initialize(conversation:, user:, params:)
    @conversation = conversation
    @user = user
    @params = params
  end

  def create!
    raise Invalid, 'Disponível só para números conectados por QR Code.' unless wppconnect?

    kind = @params[:kind].to_s
    raise Invalid, 'Tipo de mensagem desconhecido.' unless KINDS.include?(kind)

    message = @conversation.messages.new(account_id: @conversation.account_id, inbox_id: @conversation.inbox_id,
                                         message_type: :outgoing, sender: @user)
    send(:"build_#{kind}", message)
    message.save!
    message
  end

  private

  def wppconnect?
    OmnichannelCrm::ConnectionsService.provider(@conversation.inbox) == 'wppconnect'
  end

  def build_location(message)
    lat = Float(@params[:lat], exception: false)
    lng = Float(@params[:lng], exception: false)
    raise Invalid, 'Informe uma localização válida.' if lat.nil? || lng.nil? || lat.abs > 90 || lng.abs > 180

    name = text(:name, 100)
    address = text(:address, 300)
    message.attachments.build(account_id: message.account_id, file_type: :location, coordinates_lat: lat, coordinates_long: lng,
                              fallback_title: address || name || format('%<lat>.6f, %<lng>.6f', lat: lat, lng: lng),
                              meta: { name: name }.compact)
  end

  def build_contact(message)
    phone = @params[:phone].to_s.gsub(/\D/, '')
    raise Invalid, 'Informe o telefone do contato com DDD.' if phone.length < 10

    name = text(:name, 100) || phone
    message.attachments.build(account_id: message.account_id, file_type: :contact, fallback_title: "+#{phone}",
                              meta: { firstName: name })
  end

  def build_poll(message)
    name = text(:name, 255)
    options = list_of(@params[:options]).map { |option| option.to_s.strip.truncate(100) }.compact_blank.uniq
    raise Invalid, 'Escreva a pergunta da enquete.' if name.blank?
    raise Invalid, "A enquete precisa de 2 a #{MAX_POLL_OPTIONS} opções diferentes." unless options.size.between?(2, MAX_POLL_OPTIONS)

    multiple = ActiveModel::Type::Boolean.new.cast(@params[:multiple])
    message.content = (["📊 *#{name}*"] + options.map { |option| "▫️ #{option}" }).join("\n")
    message.content_attributes = { 'whatsapp_poll' => { 'name' => name, 'options' => options,
                                                        'selectable_count' => multiple ? 0 : 1 } }
  end

  def build_list(message)
    description = text(:description, 1000)
    button_text = text(:button_text, 20) || 'Ver opções'
    rows = list_of(@params[:rows]).filter_map { |row| list_row(row) }.first(MAX_LIST_ROWS)
    raise Invalid, 'Escreva o texto da mensagem.' if description.blank?
    raise Invalid, 'Adicione pelo menos uma opção.' if rows.empty?

    section = { 'title' => text(:section_title, 24) || 'Opções',
                'rows' => rows.each_with_index.map { |row, index| row.merge('rowId' => "opcao-#{index + 1}") } }
    message.content = (["📋 #{description}"] + rows.map { |row| "▫️ #{row['title']}" } + ["[#{button_text}]"]).join("\n")
    message.content_attributes = { 'whatsapp_list' => { 'description' => description, 'button_text' => button_text,
                                                        'sections' => [section] } }
  end

  def list_row(row)
    row = row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row.to_h
    title = row['title'].to_s.strip.truncate(24)
    return if title.blank?

    { 'title' => title, 'description' => row['description'].to_s.strip.truncate(72) }
  end

  def text(key, limit)
    @params[key].to_s.strip.truncate(limit).presence
  end

  def list_of(value)
    value = value.values if value.respond_to?(:values) && !value.is_a?(Array)
    Array(value)
  end
end
