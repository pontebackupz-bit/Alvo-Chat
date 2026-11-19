# WhatsApp numbers of the account. Everyone sees the numbers they can
# access (administrators all of them); reconnecting is for administrators and
# supervisors.
class OmnichannelCrm::ConnectionsController < OmnichannelCrm::ApplicationController
  before_action :authorize_reconnect!, only: :reconnect

  def index
    render json: { connections: service.perform }
  end

  def reconnect
    inbox = service.find(params[:id])
    OmnichannelCrm::ConnectionsService.reconnect(inbox)
    audit!('connection_reconnected', subject: inbox)
    head :accepted
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def service
    @service ||= OmnichannelCrm::ConnectionsService.new(account: current_account, user: current_user)
  end

  def authorize_reconnect!
    return if current_account.account_users.find_by(user_id: current_user.id)&.administrator? || authorization.supervisor?

    render json: { error: 'Somente administradores e supervisores podem reconectar números.' }, status: :forbidden
  end
end
