# Turns one EZ.Chat (Hyperflow) node into a block the native runner executes.
#
# `convert` returns `{ type:, data:, handles: }`; `handles` maps the node's
# original output names to the runner's (menu buttons of every channel become
# `option:<id>`, "out of context" becomes `other`). Outputs missing from the
# map keep their name.
class OmnichannelCrm::WorkflowImporters::EzChatNodeConverter
  MENU_HINT = /(clique|aperte|apertando|toque).*(bot[aã]o|menu)|bot[aã]o abaixo/i
  MENU_HINT_TEXT = '💡 _Responda com o *número* da opção desejada:_'.freeze
  VALIDATORS = { 'cpfCnpj' => 'cpf_cnpj', 'cpf' => 'cpf_cnpj', 'cnpj' => 'cpf_cnpj', 'number' => 'number', 'email' => 'email' }.freeze
  MEDIA_TYPES = %w[image video audio file document].freeze
  CHANNEL_ORDER = %w[whatsapp default].freeze

  def initialize(type, data)
    @type = type
    @data = data
  end

  def convert
    case @type
    when 'start' then block('start', {})
    when 'chat' then chat
    when 'conditional' then branch
    when 'flowVariable', 'userVariable' then variables
    when 'split' then block('split', 'splits' => Array(@data['splits']).map { |split| split.slice('id', 'value') })
    when 'startInactivity' then block('inactivity', 'minutes' => @data['inactivityMinutes'].to_i)
    else attendance_or_other
    end&.tap { |result| result[:data]['title'] ||= @data['title'].presence }
  end

  private

  def block(type, data, handles = {})
    { type: type, data: data, handles: handles }
  end

  def attendance_or_other
    case @type
    when 'handoverAttendance'
      block('transfer_team', 'team_id' => nil, 'team_name' => @data.dig('department', 'name').to_s.strip,
                             'distribute' => true, 'wait_for_agent' => true)
    when 'onlineAgentAttendance' then online_agent
    when 'labelAttendance'
      block('add_label', 'labels' => Array(@data['labels']).filter_map { |label| OmnichannelCrm::WorkflowRunner.label_title(label['name']) })
    when 'jump' then subflow
    else integrations_or_notes
    end
  end

  def integrations_or_notes
    case @type
    when 'code' then block('code', 'code' => @data['code'].to_s)
    when 'oracleDB' then block('integration', 'provider' => 'oracle', 'query' => @data['query'].to_s)
    when 'googleSheets'
      block('integration', 'provider' => 'google_sheets', 'sheet' => @data.dig('worksheet', 'name'), 'payload' => @data['sheetPayload'])
    when 'json' then block('end', 'resolve' => false)
    when 'annotation', 'notes' then block('note', 'text' => note_text)
    end
  end

  def online_agent
    by_template = ActiveModel::Type::Boolean.new.cast(@data['transferByEmailUsername'])
    email = by_template ? @data['agentEmailUsername'] : @data.dig('agent', 'email')
    block('assign_agent', 'agent_id' => nil, 'agent_email' => email.to_s, 'agent_name' => @data.dig('agent', 'name'),
                          'team_name' => @data.dig('department', 'name').to_s.strip, 'only_if_online' => true)
  end

  def subflow
    flow = @data['flow']
    name = flow.is_a?(Hash) ? flow['name'] : flow
    block('subflow', 'flow_name' => name.to_s, 'data' => @data['data'].to_s,
                     'returns' => ActiveModel::Type::Boolean.new.cast(@data['returnOptions']) || false)
  end

  def branch
    rules = Array(@data['conditions']).filter_map do |condition|
      next unless condition.is_a?(Hash)

      { 'id' => condition['id'].to_s, 'left' => condition['left'].to_s, 'operator' => condition['comparator'].to_s,
        'right' => condition['right'].to_s, 'label' => condition['label'] }.compact
    end
    block('branch', 'rules' => rules)
  end

  def variables
    values = JSON.parse(@data['data'].presence || '{}')
    block('set_variables', 'scope' => @type == 'userVariable' ? 'contact' : 'flow', 'values' => values.is_a?(Hash) ? values : {})
  rescue JSON::ParserError
    block('set_variables', 'scope' => @type == 'userVariable' ? 'contact' : 'flow', 'values' => {}, 'invalid' => @data['data'])
  end

  def note_text
    @data['markdown'].presence ||
      Array(@data['comments']).filter_map { |comment| comment.is_a?(Hash) ? comment['comment'] : nil }.join("\n\n")
  end

  # Chat blocks become a message, a question (typed answer) or a menu.
  def chat
    channel = primary_channel
    content = message_text(channel).presence || ordered_channels.map { |item| message_text(item) }.find(&:present?).to_s
    attachments = media(channel)
    options, handles = menu_options
    return menu(content, attachments, options, handles) if options.any?
    return question(content, attachments) if channels.values.any? { |item| item['waitInput'] }

    block('send_message', { 'content' => content, 'attachments' => attachments }.compact_blank)
  end

  def menu(content, attachments, options, handles)
    hinted = content.lines.map { |line| line.include?('💡') && line.match?(MENU_HINT) ? "#{MENU_HINT_TEXT}\n" : line }.join.strip
    channels.each_key { |key| handles["#{key}-outOfContext"] = 'other' }
    block('menu', { 'content' => hinted, 'options' => options, 'attachments' => attachments }.compact_blank, handles)
  end

  def question(content, attachments)
    settings = channels.values.find { |item| item['waitInput'] } || {}
    handles = channels.keys.flat_map { |key| [["#{key}-waitInput", 'next'], ["#{key}-waitInputMaxRetries", 'max_retries']] }.to_h
    block('ask_question', {
      'content' => content, 'attachments' => attachments, 'validator' => VALIDATORS[settings['waitInputValidator'].to_s],
      'retries' => settings['waitInputRetriesNumber'].to_i, 'retry_message' => settings['waitInputRetryMessage'].presence
    }.compact_blank, handles)
  end

  def channels
    @data['channels'].is_a?(Hash) ? @data['channels'] : {}
  end

  # WhatsApp's version of the content, since that is where it is sent.
  def primary_channel
    CHANNEL_ORDER.filter_map { |key| channels[key] }.find { |item| Array(item['attachments']).any? } || channels.values.first || {}
  end

  def message_text(channel)
    Array(channel['attachments']).filter_map do |attachment|
      case attachment['type']
      when 'text' then attachment['text'].to_s.strip.presence
      when 'list' then [attachment['header'], attachment['content']].compact_blank.join("

").strip.presence
      when 'contact' then "*#{attachment['name']}*\n#{[attachment['country'], attachment['phone']].compact_blank.join(' ')}"
      end
    end.join("\n\n")
  end

  def media(channel)
    Array(channel['attachments']).filter_map do |attachment|
      next unless MEDIA_TYPES.include?(attachment['type']) && attachment['url'].present?

      { 'type' => attachment['type'] == 'image' ? 'image' : 'file', 'url' => attachment['url'] }
    end
  end

  # The options are the buttons of the first channel that has any
  # (WhatsApp's, where the menu is sent). Buttons of the other channels lead
  # to the same option when they share its label, its payload or its
  # position; their labels become synonyms.
  def menu_options
    lists = ordered_channels.flat_map { |channel| button_groups(channel) }.reject(&:empty?)
    return [[], {}] if lists.empty?

    options = lists.first.map { |button| new_option(button) }
    handles = options.to_h { |option| [option['id'], "option:#{option['id']}"] }
    lists.drop(1).each do |list|
      list.each_with_index { |button, index| link_button(options, handles, button, list.size == options.size ? index : nil) }
    end
    [options.reject { |option| option['label'].blank? }, handles]
  end

  def ordered_channels
    (CHANNEL_ORDER.filter_map { |key| channels[key] } + channels.except(*CHANNEL_ORDER).values).select { |item| item.is_a?(Hash) }
  end

  def new_option(button)
    label = button['label'].to_s.strip
    { 'id' => button['id'].to_s, 'label' => label, 'synonyms' => Array(button['synonyms']).map(&:to_s).uniq - [label],
      'payload' => payload(button['payload']) }
  end

  def link_button(options, handles, button, index)
    label = comparable(button['label'])
    option = options.find { |candidate| comparable(candidate['label']) == label && label.present? } ||
             options.find { |candidate| candidate['payload'].present? && candidate['payload'] == payload(button['payload']) } ||
             (options[index] if index)
    return unless option

    option['synonyms'] = (option['synonyms'] + [button['label'].to_s.strip, *Array(button['synonyms'])]).compact_blank.uniq - [option['label']]
    option['payload'] = payload(button['payload']).merge(option['payload'])
    handles[button['id'].to_s] = "option:#{option['id']}"
  end

  def comparable(text)
    ActiveSupport::Inflector.transliterate(text.to_s).downcase.squish
  end

  # Each attachment's buttons (or list items) and the quick replies are
  # separate groups: a channel often repeats the same choices in both.
  def button_groups(channel)
    groups = Array(channel['attachments']).map do |attachment|
      Array(attachment['buttons']) + Array(attachment['sections']).flat_map { |section| Array(section['buttons']) }
    end
    (groups + [Array(channel['quickReplies'])]).map do |group|
      group.select { |button| button.is_a?(Hash) && button['id'].present? }.uniq { |button| button['id'] }
    end
  end

  def payload(raw)
    parsed = raw.is_a?(String) ? JSON.parse(raw.presence || '{}') : raw
    parsed.is_a?(Hash) ? parsed : {}
  rescue JSON::ParserError
    {}
  end
end
