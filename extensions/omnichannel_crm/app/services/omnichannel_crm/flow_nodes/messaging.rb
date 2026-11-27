# Blocks that talk to the customer: messages, questions and menus.
module OmnichannelCrm::FlowNodes::Messaging
  VALIDATORS = {
    'cpf_cnpj' => ->(text) { [11, 14].include?(text.gsub(/\D/, '').length) },
    'number' => ->(text) { text.match?(/\A\s*-?\d+([.,]\d+)?\s*\z/) },
    'email' => ->(text) { text.match?(URI::MailTo::EMAIL_REGEXP) }
  }.freeze
  MAX_ATTACHMENT_BYTES = 15.megabytes

  private

  def execute_send_message(data)
    send_attachments(data['attachments'])
    send_message(data['content'])
    'next'
  end

  def execute_ask_question(data)
    send_attachments(data['attachments'])
    send_message(data['content'])
    :wait_reply
  end

  def execute_menu(data)
    send_attachments(data['attachments'])
    send_message(menu_text(data))
    :wait_reply
  end

  # The output for a customer reply; nil keeps waiting (the menu is sent
  # again) and :retry keeps waiting after asking the question again.
  def reply_handle(node, text)
    case node['type']
    when 'ask_question' then question_handle(node, text)
    when 'menu' then menu_handle(node, text)
    end
  end

  def question_handle(node, text)
    data = node['data'] || {}
    validator = VALIDATORS[data['validator'].to_s]
    return retry_question(node, data) if validator && !validator.call(text)

    variable = data['variable'].presence
    remember('input' => { 'text' => text }, '__retries' => retries.except(node['id']))
    remember(variable => text) if variable
    'next'
  end

  def retry_question(node, data)
    attempts = retries[node['id']].to_i + 1
    if attempts > data['retries'].to_i
      remember('__retries' => retries.except(node['id']), 'input' => nil)
      return 'max_retries'
    end

    remember('__retries' => retries.merge(node['id'] => attempts))
    send_message(data['retry_message'].presence || data['content'])
    :retry
  end

  def retries
    run.variables['__retries'].is_a?(Hash) ? run.variables['__retries'] : {}
  end

  # Matches the option number ("2"), its text or a synonym. Unknown answers
  # follow the "other" output when it is connected, otherwise the menu is
  # sent again. The chosen option's payload becomes `input`.
  def menu_handle(node, text)
    options = visible_options(node['data'])
    index = text[/\A\s*(\d+)\s*[.)-]?\s*\z/, 1]&.to_i
    option = (options[index - 1] if index&.between?(1, options.size)) ||
             options.find { |candidate| option_words(candidate).include?(normalize_words(text)) }
    if option
      payload = option['payload'].is_a?(Hash) ? option['payload'] : {}
      remember('input' => payload.merge('text' => text, 'label' => option['label'], 'id' => option['id']))
      return "option:#{option['id']}"
    end

    next_node_id(node, 'other') ? 'other' : nil
  end

  def option_words(option)
    [option['label'], *Array(option['synonyms'])].map { |word| normalize_words(word) }
  end

  def normalize_words(text)
    ActiveSupport::Inflector.transliterate(text.to_s).downcase.squish
  end

  def visible_options(data)
    Array((data || {})['options']).select { |option| option['label'].to_s.strip.present? }
  end

  def menu_text(data)
    options = visible_options(data).each_with_index.map { |option, index| "#{index + 1}. #{option['label'].to_s.strip}" }
    [data['content'].presence, options.join("\n").presence].compact.join("\n\n")
  end

  def send_message(content)
    text = template.render(content.to_s).strip
    return true if text.blank?

    conversation.messages.create!(account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :outgoing,
                                  content: text, content_attributes: { 'crm_workflow_run_id' => run.id })
  end

  # Images and files configured by URL; a file that cannot be downloaded
  # is sent as its link.
  def send_attachments(attachments)
    Array(attachments).each do |attachment|
      url = template.render(attachment['url'].to_s).strip
      next unless url.match?(%r{\Ahttps?://}i)

      send_attachment(url, attachment['type'])
    rescue Down::Error, ActiveRecord::RecordInvalid => e
      Rails.logger.warn("Workflow run #{run.id} could not send #{url}: #{e.message}")
      send_message(url)
    end
  end

  def send_attachment(url, type)
    file = Down.download(url, max_size: MAX_ATTACHMENT_BYTES)
    message = conversation.messages.new(account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :outgoing,
                                        content_attributes: { 'crm_workflow_run_id' => run.id })
    message.attachments.new(account_id: conversation.account_id, file_type: type == 'image' ? :image : :file,
                            file: { io: file, filename: file.original_filename.presence || File.basename(URI(url).path) })
    message.save!
  end
end
