# CSAT for the WhatsApp bridges (WPPConnect and Baileys). The survey goes out
# as text asking for a 1-5 reply; that reply, sent after the conversation was
# resolved, is stored as the survey response instead of opening a new
# conversation.
class OmnichannelCrm::CsatReplyService
  PROVIDERS = %w[wppconnect baileys].freeze
  REPLY_WINDOW = 3.days
  RATING = /\A\s*([1-5])(?:\s*(?:[-–.:)]|\z).*)?\z/m
  INSTRUCTIONS = <<~TEXT.strip.freeze
    Responda com uma nota de 1 a 5:
    1 - Muito insatisfeito
    2 - Insatisfeito
    3 - Neutro
    4 - Satisfeito
    5 - Muito satisfeito
  TEXT
  THANKS = 'Obrigado pela sua avaliação!'.freeze

  def self.bridge_survey?(message)
    channel = message.inbox&.channel
    message.template? && message.input_csat? && channel.is_a?(Channel::Api) &&
      PROVIDERS.include?(channel.additional_attributes&.dig('provider'))
  end

  # `source_id` is the WhatsApp message id, so a webhook delivered twice is
  # recognised as the same rating.
  def initialize(contact_inbox:, content:, source_id: nil)
    @contact_inbox = contact_inbox
    @content = content
    @source_id = source_id
  end

  # True when the message was taken as a rating.
  def perform
    rating = content.to_s.match(RATING)&.captures&.first
    return false if rating.nil? || contact_inbox.conversations.open.exists?
    return true if already_recorded?

    survey = pending_survey
    return false unless survey

    record(survey, rating.to_i)
    true
  end

  private

  attr_reader :contact_inbox, :content, :source_id

  # Checked in Ruby: Message's `store` re-encodes content_attributes as a JSON
  # string on update, so JSON operators do not see the key.
  def already_recorded?
    return false if source_id.blank?

    ::Message.where(conversation_id: contact_inbox.conversations.select(:id), content_type: :input_csat)
             .where(created_at: REPLY_WINDOW.ago..)
             .any? { |survey| survey.content_attributes['csat_reply_source_id'] == source_id.to_s }
  end

  def pending_survey
    ::Message.where(conversation_id: contact_inbox.conversations.resolved.select(:id), content_type: :input_csat)
             .where(created_at: REPLY_WINDOW.ago..)
             .where.missing(:csat_survey_response)
             .order(created_at: :desc).first
  end

  def record(survey, rating)
    attributes = survey.content_attributes.merge('submitted_values' => { 'csat_survey_response' => { 'rating' => rating } },
                                                 'csat_reply_source_id' => source_id.to_s.presence)
    survey.update!(content_attributes: attributes)
    CsatSurveys::ResponseBuilder.new(message: survey).perform
    survey.conversation.messages.create!(account_id: survey.account_id, inbox_id: survey.inbox_id, message_type: :outgoing,
                                         content: THANKS)
  end
end
