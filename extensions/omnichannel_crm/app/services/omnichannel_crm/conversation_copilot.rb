# "Perguntar ao Copiloto": answers the agent's questions about the open
# conversation (what the customer wants, what was promised, how to reply...)
# with Groq, reading the conversation itself and the contact's details.
class OmnichannelCrm::ConversationCopilot
  class Unavailable < StandardError; end

  MAX_MESSAGES = 80
  MAX_TURNS = 10
  INSTRUCTIONS = <<~TEXT.freeze
    Você é o Copiloto do AlvoChat, assistente dos atendentes.
    Responda sempre em português do Brasil, de forma direta e curta, usando apenas
    as informações da conversa e do contato abaixo. Se a resposta não estiver nelas,
    diga isso claramente em vez de inventar. Quando pedirem uma mensagem para o
    cliente, escreva só o texto pronto para enviar, cordial e objetivo.
  TEXT

  def initialize(conversation:, user:)
    @conversation = conversation
    @user = user
  end

  # `history`: earlier turns of this chat with the copilot,
  # [{ 'role' => 'user'|'assistant', 'content' => '...' }].
  def ask(question, history = [])
    raise Unavailable, 'A IA não está configurada: defina GROQ_API_KEY no servidor.' unless OmnichannelCrm::GroqLlm.enabled?
    raise ArgumentError, 'Escreva uma pergunta.' if question.to_s.strip.blank?

    Llm::Config.with_api_key(OmnichannelCrm::GroqLlm.api_key, api_base: OmnichannelCrm::GroqLlm::API_BASE) do |context|
      chat = context.chat(model: OmnichannelCrm::GroqLlm.model, **OmnichannelCrm::GroqLlm.chat_options)
      chat.with_instructions("#{INSTRUCTIONS}\n#{context_text}")
      turns(history).each { |turn| chat.add_message(role: turn['role'].to_sym, content: turn['content']) }
      chat.ask(question.to_s.strip).content.to_s.strip
    end
  end

  private

  def turns(history)
    Array(history).last(MAX_TURNS).filter_map do |turn|
      turn = turn.to_h.stringify_keys
      next unless %w[user assistant].include?(turn['role']) && turn['content'].present?

      { 'role' => turn['role'], 'content' => turn['content'].to_s.truncate(4000) }
    end
  end

  def context_text
    contact = @conversation.contact
    <<~TEXT
      Atendente: #{@user.name}
      Cliente: #{contact&.name} #{contact&.phone_number}
      Conversa nº #{@conversation.display_id} (#{status_label})#{" · Time: #{@conversation.team.name}" if @conversation.team}

      Mensagens (mais antigas primeiro):
      #{transcript}
    TEXT
  end

  def status_label
    { 'open' => 'aberta', 'resolved' => 'resolvida', 'pending' => 'pendente', 'snoozed' => 'pausada' }
      .fetch(@conversation.status, @conversation.status)
  end

  def transcript
    messages = @conversation.messages.where(message_type: %i[incoming outgoing]).where(private: false)
                            .includes(:sender, :attachments).reorder(created_at: :desc, id: :desc).limit(MAX_MESSAGES).to_a.reverse
    return '(sem mensagens)' if messages.empty?

    messages.map { |message| line(message) }.join("\n")
  end

  def line(message)
    who = message.incoming? ? 'Cliente' : (message.sender&.name.presence || 'Atendente')
    text = message.content.to_s.strip.presence || attachment_text(message)
    "[#{message.created_at.in_time_zone.strftime('%d/%m %H:%M')}] #{who}: #{text.to_s.truncate(1000)}"
  end

  def attachment_text(message)
    message.attachments.map { |attachment| describe(attachment) }.join(' ').presence || '(sem texto)'
  end

  def describe(attachment)
    return "(arquivo: #{attachment.file.filename})" if attachment.file.attached? && attachment.file_type == 'file'
    return "(#{attachment.file_type})" unless attachment.file_type == 'contact'

    name = attachment.meta.to_h.values_at('firstName', 'lastName').compact_blank.join(' ')
    "(contato compartilhado: #{[name.presence, attachment.fallback_title].compact.join(' ')})"
  end
end
