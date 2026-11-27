# Turns WhatsApp audio into text with Groq's Whisper (same GROQ_API_KEY as the
# AI box). The text is kept on the attachment (`meta.transcribed_text`), which
# the audio player already shows below the audio.
class OmnichannelCrm::AudioTranscription
  class Unavailable < StandardError; end

  DEFAULT_MODEL = 'whisper-large-v3-turbo'.freeze
  # Groq's file limit for transcriptions (25 MB, decimal).
  BYTE_LIMIT = 25_000_000

  def self.enabled?
    OmnichannelCrm::GroqLlm.enabled?
  end

  def self.model
    ENV.fetch('GROQ_TRANSCRIPTION_MODEL', '').strip.presence || DEFAULT_MODEL
  end

  def initialize(attachment)
    @attachment = attachment
  end

  def perform
    existing = @attachment.meta.to_h['transcribed_text']
    return existing if existing.present?
    raise Unavailable, 'A transcrição usa a IA do Groq: defina GROQ_API_KEY no servidor.' unless self.class.enabled?
    raise Unavailable, 'Este anexo não é um áudio.' unless @attachment.file_type == 'audio' && @attachment.file.attached?
    raise Unavailable, 'Áudio grande demais para transcrever (limite de 25 MB).' if @attachment.file.byte_size > BYTE_LIMIT

    text = transcribe
    save(text)
    text
  end

  private

  def transcribe
    @attachment.file.blob.open do |file|
      response = client.audio.transcribe(parameters: { model: self.class.model, file: file, language: 'pt', temperature: 0.0 })
      response['text'].to_s.strip
    end
  end

  def save(text)
    return if text.blank?

    @attachment.update!(meta: @attachment.meta.to_h.merge('transcribed_text' => text))
    @attachment.message&.reload&.send_update_event
  end

  def client
    OpenAI::Client.new(access_token: OmnichannelCrm::GroqLlm.api_key, uri_base: 'https://api.groq.com/openai/',
                       request_timeout: 120)
  end
end
