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

  # Brings the chats already on the phone into AlvoChat, in the background.
  def import_history
    inbox = service.find(params[:id])
    raise OmnichannelCrm::ConnectionRegistration::NotAllowed, 'Só números conectados por QR Code têm histórico para importar.' unless
      OmnichannelCrm::ConnectionsService.provider(inbox) == 'wppconnect'

    raise OmnichannelCrm::ConnectionRegistration::NotAllowed, 'O número está desconectado. Conecte-o antes de importar o histórico.' unless
      OmnichannelCrm::WhatsappHistoryImport.online?(inbox)

    attributes = inbox.channel.additional_attributes.to_h
    inbox.channel.update!(additional_attributes: attributes.merge('history_import' => { 'status' => 'queued',
                                                                                         'updated_at' => Time.current.iso8601 }))
    OmnichannelCrm::WhatsappHistoryImportJob.perform_later(inbox.id, history_limit(:chats), history_limit(:messages))
    audit!('connection_history_imported', subject: inbox)
    head :accepted
  end

  # Brings the contacts saved on the phone into Contatos, in the background.
  def import_contacts
    inbox = service.find(params[:id])
    raise OmnichannelCrm::ConnectionRegistration::NotAllowed, 'Só números conectados por QR Code têm contatos para importar.' unless
      OmnichannelCrm::ConnectionsService.provider(inbox) == 'wppconnect'

    raise OmnichannelCrm::ConnectionRegistration::NotAllowed, 'O número está desconectado. Conecte-o antes de importar os contatos.' unless
      OmnichannelCrm::WhatsappHistoryImport.online?(inbox)

    attributes = inbox.channel.additional_attributes.to_h
    inbox.channel.update!(additional_attributes: attributes.merge('contacts_import' => { 'status' => 'queued',
                                                                                          'updated_at' => Time.current.iso8601 }))
    OmnichannelCrm::WhatsappContactImportJob.perform_later(inbox.id)
    audit!('connection_contacts_imported', subject: inbox)
    head :accepted
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
    inbox = registration.create(name: params[:name], team_id: params.key?(:team_id) ? params[:team_id] : :own)
    audit!('connection_created', subject: inbox)
    render json: { id: inbox.id }.merge(safe_state(inbox)), status: :created
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    inbox = registration.update(service.find(params[:id]), name: params[:name],
                                                           team_id: params.key?(:team_id) ? params[:team_id] : :keep,
                                                           owner_id: params.key?(:owner_id) ? params[:owner_id] : :keep)
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

  def history_limit(key)
    params[key].present? ? params[key].to_i.clamp(1, 500) : 100
  end

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
