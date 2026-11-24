# Lets any user register and manage their own WhatsApp number (WPPConnect,
# by QR code) without the administrator-only inbox settings. The person who
# registers it becomes a member of the inbox so they see its conversations;
# supervisors of its default team see them through their team scope.
class OmnichannelCrm::ConnectionRegistration
  class NotAllowed < StandardError; end

  def initialize(account:, user:)
    @account = account
    @user = user
  end

  # `team_id`: a team, nil for none, or :own for the person's own team.
  def create(name:, team_id: :own)
    raise ArgumentError, 'Informe um nome para o número.' if name.to_s.strip.blank?

    # The number belongs to whoever registers it, and to their team unless
    # another one is chosen: its new conversations go to them.
    team = team_id == :own ? own_team : (team_id.present? ? @account.teams.find(team_id) : nil)
    inbox = ActiveRecord::Base.transaction do
      channel = Channel::Api.create!(account: @account, additional_attributes: {
                                       'provider' => 'wppconnect', 'created_by_id' => @user.id, 'owner_id' => @user.id,
                                       'default_team_id' => team&.id
                                     }.compact)
      @account.inboxes.create!(name: name.to_s.strip, channel: channel).tap do |record|
        channel.update!(additional_attributes: channel.additional_attributes.merge('session_id' => session_id_for(record)))
        InboxMember.find_or_create_by!(inbox: record, user: @user)
      end
    end
    OmnichannelCrm::WppconnectBridgeClient.new.create_session(session_id_for(inbox))
    inbox
  end

  def update(inbox, name: nil, team_id: :keep, owner_id: :keep)
    authorize_manage!(inbox)
    inbox.update!(name: name.to_s.strip) if name.to_s.strip.present?
    attributes = inbox.channel.additional_attributes.to_h
    attributes['default_team_id'] = (team_id.present? ? @account.teams.find(team_id).id : nil) unless team_id == :keep
    attributes['owner_id'] = owner_for(owner_id, inbox)&.id unless owner_id == :keep
    inbox.channel.update!(additional_attributes: attributes.compact)
    inbox
  end

  # Only numbers without conversations can be removed here, so no history is
  # lost by accident; the administrator settings handle the rest.
  def destroy(inbox)
    authorize_manage!(inbox)
    raise NotAllowed, 'Este número já tem conversas. Peça a um administrador para removê-lo.' if inbox.conversations.exists?

    session_id = inbox.channel.additional_attributes.to_h['session_id']
    begin
      OmnichannelCrm::WppconnectBridgeClient.new.delete_session(session_id) if session_id.present?
    rescue StandardError => e
      Rails.logger.warn("Could not close WPPConnect session #{session_id}: #{e.message}")
    end
    inbox.destroy!
  end

  # The person who receives the number's new conversations; they become a
  # member of the inbox so they can open them.
  def owner_for(owner_id, inbox)
    return if owner_id.blank?

    owner = @account.users.find(owner_id)
    InboxMember.find_or_create_by!(inbox: inbox, user: owner)
    owner
  end

  def can_manage?(inbox)
    administrator? || supervisor? || inbox.channel.try(:additional_attributes).to_h['created_by_id'].to_i == @user.id
  end

  private

  def authorize_manage!(inbox)
    raise NotAllowed, 'Só quem cadastrou o número, supervisores e administradores podem alterá-lo.' unless can_manage?(inbox)
  end

  def own_team
    @account.teams.joins(:team_members).where(team_members: { user_id: @user.id }).order(:id).first
  end

  def session_id_for(inbox)
    "account-#{@account.id}-inbox-#{inbox.id}"
  end

  def administrator?
    return @administrator if defined?(@administrator)

    @administrator = @account.account_users.find_by(user_id: @user.id)&.administrator? || false
  end

  def supervisor?
    return @supervisor if defined?(@supervisor)

    @supervisor = OmnichannelCrm::Authorization.new(account: @account, user: @user).supervisor?
  end
end
