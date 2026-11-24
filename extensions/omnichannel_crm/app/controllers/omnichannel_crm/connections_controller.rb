# WhatsApp numbers of the account. Everyone sees, reconnects and registers
# numbers here (administrators see all of them, others the ones they can
# access); renaming and removing is for whoever registered the number,
# supervisors and administrators.
class OmnichannelCrm::ConnectionsController < OmnichannelCrm::ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
  rescue_from OmnichannelCrm::ConnectionRegistration::NotAllowed, with: ->(e) { render json: { error: e.message }, status: :forbidden }

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

  # New number: returns its id and the QR code to scan.
  def create
    inbox = registration.create(name: params[:name], team_id: params[:team_id])
    audit!('connection_created', subject: inbox)
    render json: { id: inbox.id }.merge(safe_state(inbox)), status: :created
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    inbox = registration.update(service.find(params[:id]), name: params[:name],
                                                           team_id: params.key?(:team_id) ? params[:team_id] : :keep)
    audit!('connection_updated', subject: inbox)
    head :no_content
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    inbox = service.find(params[:id])
    registration.destroy(inbox)
    audit!('connection_deleted', metadata: { inbox_id: inbox.id, name: inbox.name })
    head :no_content
  end

  private

  def service
    @service ||= OmnichannelCrm::ConnectionsService.new(account: current_account, user: current_user)
  end

  def registration
    @registration ||= OmnichannelCrm::ConnectionRegistration.new(account: current_account, user: current_user)
  end

  # The bridge may need a moment before the QR code exists.
  def safe_state(inbox)
    OmnichannelCrm::ConnectionsService.session_state(inbox)
  rescue StandardError => e
    { status: 'connecting', error: e.message }
  end
end
