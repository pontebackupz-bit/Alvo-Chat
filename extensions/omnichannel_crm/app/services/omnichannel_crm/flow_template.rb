# Renders `{{ ... }}` placeholders of chatbot flows.
#
# Expressions are a small, safe subset of what EZ.Chat flows use: paths
# (`flow.setor`, `user.cpfCnpj`, `input[0].EMAIL`, `input.agents[input.agents.length-1]`),
# `.length`, literals (numbers, quoted strings, true/false/null) and `+`/`-`.
# Nothing is evaluated as code. Unknown paths render as blank.
#
# Roots come from `resolver`, called with the first name of a path.
class OmnichannelCrm::FlowTemplate
  PLACEHOLDER = /\{\{(.*?)\}\}/m
  WHOLE = /\A\s*\{\{(.*?)\}\}\s*\z/m
  TOKEN = /\s*(?:(\d+(?:\.\d+)?)|("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')|([[:alpha:]_$][[:alnum:]_$]*)|(\S))/
  LITERALS = { 'true' => true, 'false' => false, 'null' => nil, 'undefined' => nil }.freeze

  class SyntaxError < StandardError; end

  def initialize(&resolver)
    @resolver = resolver
  end

  # Text with every placeholder replaced by its value.
  def render(text)
    text.to_s.gsub(PLACEHOLDER) { display(evaluate(Regexp.last_match(1))) }
  end

  # A value keeping its type when the template is a single placeholder
  # (`"{{flow.count + 1}}"` is a number); other strings are rendered.
  def value(template)
    case template
    when String then (match = template.match(WHOLE)) ? evaluate(match[1]) : render(template)
    when Hash then template.transform_values { |item| value(item) }
    when Array then template.map { |item| value(item) }
    else template
    end
  end

  def evaluate(source)
    @tokens = source.to_s.scan(TOKEN).map { |number, string, name, symbol| token(number, string, name, symbol) }
    @position = 0
    result = additive
    raise SyntaxError, source unless @position == @tokens.size

    result
  rescue SyntaxError, ZeroDivisionError
    nil
  end

  # JavaScript-like truthiness, which is what imported conditions expect.
  def self.truthy?(value)
    !(value.nil? || value == false || value == '' || (value.is_a?(Numeric) && value.zero?))
  end

  def self.number(value)
    return value if value.is_a?(Numeric)
    return 0 if value.nil? || value == '' || value == false
    return 1 if value == true

    Float(value.to_s.tr(',', '.')).then { |float| (float % 1).zero? ? float.to_i : float }
  rescue ArgumentError
    nil
  end

  private

  def token(number, string, name, symbol)
    return [:literal, number.include?('.') ? number.to_f : number.to_i] if number
    return [:literal, string[1..-2].gsub(/\\(.)/, '\1')] if string
    return [:name, name] if name

    [:symbol, symbol]
  end

  def additive
    result = postfix(primary)
    while (operator = accept_symbol('+', '-'))
      result = combine(result, operator, postfix(primary))
    end
    result
  end

  def combine(left, operator, right)
    left_number = self.class.number(left)
    right_number = self.class.number(right)
    return left_number.public_send(operator, right_number) if left_number && right_number
    raise SyntaxError, 'subtraction of text' if operator == '-'

    "#{display(left)}#{display(right)}"
  end

  def primary
    type, content = next_token
    case type
    when :literal then content
    when :name then LITERALS.key?(content) ? LITERALS[content] : @resolver.call(content)
    when :symbol
      raise SyntaxError, content unless content == '('

      additive.tap { expect_symbol(')') }
    else raise SyntaxError, 'unexpected end'
    end
  end

  def postfix(value)
    loop do
      if accept_symbol('.')
        type, name = next_token
        raise SyntaxError, 'property name' unless type == :name

        value = member(value, name)
      elsif accept_symbol('[')
        value = member(value, additive)
        expect_symbol(']')
      else
        return value
      end
    end
  end

  def member(value, key)
    return value.size if %w[length size].include?(key) && (value.is_a?(Array) || value.is_a?(String))

    case value
    when Hash then value[key.to_s]
    when Array then key.is_a?(Integer) ? value[key] : nil
    end
  end

  def next_token
    @tokens[@position].tap { @position += 1 } || [nil, nil]
  end

  def accept_symbol(*symbols)
    type, content = @tokens[@position]
    return unless type == :symbol && symbols.include?(content)

    @position += 1
    content
  end

  def expect_symbol(symbol)
    raise SyntaxError, symbol unless accept_symbol(symbol)
  end

  def display(value)
    case value
    when nil then ''
    when Hash, Array then value.to_json
    when Float then (value % 1).zero? ? value.to_i.to_s : value.to_s
    else value.to_s
    end
  end
end
