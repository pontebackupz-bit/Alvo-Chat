# "Transcrever" on an audio, for anyone who can open its conversation.
class OmnichannelCrm::AudioTranscriptionsController < OmnichannelCrm::ApplicationController
  def create
    attachment = ::Attachment.where(account_id: current_account.id).find(params[:attachment_id])
    context = { user: current_user, account: current_account, account_user: Current.account_user }
    return head :forbidden unless ConversationPolicy.new(context, attachment.message.conversation).show?

    render json: { text: OmnichannelCrm::AudioTranscription.new(attachment).perform.to_s }
  rescue OmnichannelCrm::AudioTranscription::Unavailable => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.warn("Audio transcription failed: #{e.class} #{e.message}")
    render json: { error: 'Não foi possível transcrever este áudio agora. Tente de novo.' }, status: :bad_gateway
  end
end
