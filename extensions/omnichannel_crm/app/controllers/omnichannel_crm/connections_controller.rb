# WhatsApp numbers of the account. Everyone sees, and can reconnect, the
# numbers they can access (administrators all of them).
class OmnichannelCrm::ConnectionsController < OmnichannelCrm::ApplicationController
  def index
    render json: { connections: service.perform }
  end

  # Starts the session again. When WhatsApp signed the number out, the answer
  # carries the QR code to scan; `show` is polled until it connects.
  def reconnect
    inbox = service.find(params[:id])
    result = OmnichannelCrm::ConnectionsService.reconnect(inbox)
    audit!('connection_reconnected', subject: inbox)
    render json: result
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def show
    render json: OmnichannelCrm::ConnectionsService.session_state(service.find(params[:id]))
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue StandardError => e
    render json: { status: 'unreachable', error: e.message }
  end

  private

  def service
    @service ||= OmnichannelCrm::ConnectionsService.new(account: current_account, user: current_user)
  end
end
