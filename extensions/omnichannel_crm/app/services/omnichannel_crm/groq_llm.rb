# Runs the AI features (reply suggestion, summary, rewrite, copilot) on Groq
# instead of OpenAI when GROQ_API_KEY is set. Groq speaks the OpenAI API, so
# only the address, the key and the model change; every feature uses the
# same Groq model (GROQ_MODEL). Without the variable nothing changes.
module OmnichannelCrm::GroqLlm
  API_BASE = 'https://api.groq.com/openai/v1'.freeze
  DEFAULT_MODEL = 'openai/gpt-oss-120b'.freeze

  module_function

  def enabled?
    api_key.present?
  end

  def api_key
    ENV.fetch('GROQ_API_KEY', '').strip.presence
  end

  def model
    ENV.fetch('GROQ_MODEL', '').strip.presence || DEFAULT_MODEL
  end

  # Groq models are not in RubyLLM's registry: ask for them as OpenAI-style.
  def chat_options
    { provider: :openai, assume_model_exists: true }
  end

  # Llm::Config (global RubyLLM setup, used by the copilot).
  module Config
    private

    def system_api_key
      OmnichannelCrm::GroqLlm.enabled? ? OmnichannelCrm::GroqLlm.api_key : super
    end

    def openai_endpoint
      OmnichannelCrm::GroqLlm.enabled? ? OmnichannelCrm::GroqLlm::API_BASE : super
    end
  end

  # Llm::BaseAiService (copilot and other enterprise features).
  module BaseAiService
    def chat(model: @model, temperature: @temperature)
      return super unless OmnichannelCrm::GroqLlm.enabled?

      RubyLLM.chat(model: model, **OmnichannelCrm::GroqLlm.chat_options).with_temperature(temperature)
    end

    private

    def setup_model
      return super unless OmnichannelCrm::GroqLlm.enabled?

      @model = OmnichannelCrm::GroqLlm.model
    end
  end

  # Captain::BaseTaskService (suggest reply, summarize, rewrite, labels).
  module TaskService
    private

    def system_api_key
      OmnichannelCrm::GroqLlm.enabled? ? OmnichannelCrm::GroqLlm.api_key : super
    end

    def api_base
      OmnichannelCrm::GroqLlm.enabled? ? OmnichannelCrm::GroqLlm::API_BASE : super
    end

    def resolved_model(model:, feature:)
      OmnichannelCrm::GroqLlm.enabled? ? OmnichannelCrm::GroqLlm.model : super
    end

    def build_chat(context, model:, messages:, schema: nil, tools: [])
      return super unless OmnichannelCrm::GroqLlm.enabled?

      chat = context.chat(model: model, **OmnichannelCrm::GroqLlm.chat_options)
      system_message = messages.find { |message| message[:role] == 'system' }
      chat.with_instructions(system_message[:content]) if system_message
      chat.with_schema(schema) if schema
      tools.each { |tool| chat = chat.with_tool(tool) }
      chat.on_end_message { |message| record_generation(chat, message, model) } if tools.any?
      chat
    end
  end
end
