class OmnichannelCrm::UsersController < OmnichannelCrm::ApplicationController
  before_action :authorize_account_administrator!
  before_action :account_user, only: [:update, :reset_password]

  def index
    account_users = current_account.account_users.includes(:user).order('users.name ASC')
    render json: {
      users: account_users.map { |record| user_payload(record) },
      counts: account_users.reorder(nil).group(:availability).count
    }
  end

  def create
    temporary_password = temporary_password()
    user = User.from_email(user_params[:email])
    new_user = user.nil?

    ActiveRecord::Base.transaction do
      user ||= create_user(temporary_password)
      raise ActiveRecord::RecordInvalid, AccountUser.new if current_account.account_users.exists?(user: user)

      @account_user = current_account.account_users.create!(
        user: user, inviter: current_user, role: user_params[:native_role], availability: :offline
      )
      apply_assignments(user)
      audit!('crm_user.created', subject: user, metadata: { account_user_id: @account_user.id })
    end

    render json: { user: user_payload(@account_user), temporary_password: new_user ? temporary_password : nil },
           status: :created
  end

  def update
    @account_user.user.update!(name: user_params[:name]) if user_params[:name].present?
    @account_user.update!(role: user_params[:native_role], availability: user_params[:availability])
    apply_assignments(@account_user.user)
    audit!('crm_user.updated', subject: @account_user.user, metadata: { account_user_id: @account_user.id })
    render json: { user: user_payload(@account_user) }
  end

  def reset_password
    password = temporary_password
    @account_user.user.update!(password: password, password_confirmation: password, tokens: {})
    @account_user.user.user_sessions.destroy_all
    audit!('crm_user.password_reset', subject: @account_user.user, metadata: { account_user_id: @account_user.id })
    render json: { temporary_password: password }
  end

  private

  def authorize_account_administrator!
    return if current_account.account_users.find_by(user: current_user)&.administrator?

    render json: { error: 'Only account administrators can manage users' }, status: :forbidden
  end

  def account_user
    @account_user = current_account.account_users.includes(:user).find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :native_role, :crm_role_id, :availability,
                                 team_ids: [], inbox_ids: [], supervised_team_ids: [])
  end

  def create_user(password)
    User.new(email: user_params[:email], name: user_params[:name], password: password, password_confirmation: password).tap do |user|
      user.skip_confirmation!
      user.save!
    end
  end

  def apply_assignments(user)
    crm_role = current_account_roles.find(user_params[:crm_role_id])
    raise ActionController::BadRequest, 'Only a platform administrator can receive the CRM administrator role' if
      crm_role.key == 'administrator' && !@account_user.administrator?

    OmnichannelCrm::RoleAssignment.find_or_initialize_by(account: current_account, user: user).update!(role: crm_role)
    replace_memberships(user, current_account.teams, user_params[:team_ids])
    replace_memberships(user, current_account.inboxes, user_params[:inbox_ids])
    replace_supervised_teams(user, crm_role)
  end

  def replace_memberships(user, scope, ids)
    records = records_for(scope, ids)
    association = scope.model_name.name == 'Team' ? user.team_members : user.inbox_members
    association.where(scope.model_name.element.to_sym => scope).destroy_all
    records.each { |record| association.find_or_create_by!(scope.model_name.element.to_sym => record) }
  end

  def replace_supervised_teams(user, crm_role)
    OmnichannelCrm::TeamSupervisor.where(account: current_account, user: user).destroy_all
    return unless crm_role.key == 'supervisor'

    records_for(current_account.teams, user_params[:supervised_team_ids]).each do |team|
      OmnichannelCrm::TeamSupervisor.create!(account: current_account, user: user, team: team)
    end
  end

  def records_for(scope, ids)
    requested_ids = Array(ids).reject(&:blank?).map(&:to_i).uniq
    records = scope.where(id: requested_ids)
    raise ActiveRecord::RecordNotFound if records.size != requested_ids.size

    records
  end

  def current_account_roles
    OmnichannelCrm::Role.where(account: current_account)
  end

  def temporary_password
    "1!aA#{SecureRandom.alphanumeric(12)}"
  end

  def user_payload(record)
    user = record.user
    {
      id: record.id,
      user_id: user.id,
      name: user.name,
      email: user.email,
      native_role: record.role,
      availability: record.availability,
      crm_role_id: OmnichannelCrm::RoleAssignment.find_by(account: current_account, user: user)&.role_id,
      team_ids: user.teams.where(account: current_account).ids,
      inbox_ids: user.inboxes.where(account: current_account).ids,
      supervised_team_ids: OmnichannelCrm::TeamSupervisor.where(account: current_account, user: user).pluck(:team_id)
    }
  end
end
