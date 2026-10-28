class OmnichannelCrm::UsersController < OmnichannelCrm::ApplicationController
  ACCESS_PROFILES = {
    'administrator' => { account_role: :administrator, crm_role_key: 'administrator' },
    'supervisor' => { account_role: :agent, crm_role_key: 'supervisor' },
    'agent' => { account_role: :agent, crm_role_key: 'seller' }
  }.freeze

  TEMPORARY_PASSWORD_WORDS = %w[brisa cedro farol jardim lagoa nuvem pedra ponte safira trigo].freeze
  PASSWORD_MODES = %w[temporary administrator].freeze

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
    return duplicate_email_error if User.from_email(user_params[:email]).present?

    password_configuration = password_setup
    return unless password_configuration

    profile = access_profile

    ActiveRecord::Base.transaction do
      user = create_user(password_configuration[:password])
      user.update!(codusur: user_params[:codusur], force_password_change: password_configuration[:force_password_change])

      @account_user = current_account.account_users.create!(
        user: user, inviter: current_user, role: profile[:account_role], availability: :offline
      )
      apply_profile_assignment(user, profile)
      audit!('crm_user.created', subject: user, metadata: { account_user_id: @account_user.id })
    end

    render json: { user: user_payload(@account_user), credentials: credentials_payload(@account_user.user, password_configuration) },
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
    password_configuration = password_setup
    return unless password_configuration

    @account_user.user.update!(
      password: password_configuration[:password],
      password_confirmation: password_configuration[:password],
      tokens: {},
      force_password_change: password_configuration[:force_password_change]
    )
    @account_user.user.user_sessions.destroy_all
    audit!('crm_user.password_reset', subject: @account_user.user, metadata: { account_user_id: @account_user.id })
    render json: { credentials: credentials_payload(@account_user.user, password_configuration) }
  end

  private

  def authorize_account_administrator!
    return if current_account.account_users.find_by(user: current_user)&.administrator?

    render json: { error: 'Apenas administradores podem gerenciar usuários.' }, status: :forbidden
  end

  def account_user
    @account_user = current_account.account_users.includes(:user).find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :codusur, :access_profile, :native_role, :crm_role_id, :availability,
                                 team_ids: [], inbox_ids: [], supervised_team_ids: [])
  end

  def password_options_params
    params.fetch(:user, ActionController::Parameters.new).permit(:password_mode, :password, :password_confirmation)
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

  def apply_profile_assignment(user, profile)
    crm_role = current_account_roles.find_by(key: profile[:crm_role_key]) || create_default_role(profile[:crm_role_key])
    OmnichannelCrm::RoleAssignment.find_or_initialize_by(account: current_account, user: user).update!(role: crm_role)
  end

  def create_default_role(key)
    definition = OmnichannelCrm::RoleDefaults::DEFINITIONS.fetch(key.to_sym)
    OmnichannelCrm::RoleDefaults.install_permissions!
    role = OmnichannelCrm::Role.create!(account: current_account, key: key, name: definition[:name])
    role.permissions = OmnichannelCrm::Permission.where(key: definition[:permissions])
    role
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
    first_word = TEMPORARY_PASSWORD_WORDS.fetch(SecureRandom.random_number(TEMPORARY_PASSWORD_WORDS.length)).capitalize
    second_word = TEMPORARY_PASSWORD_WORDS.fetch(SecureRandom.random_number(TEMPORARY_PASSWORD_WORDS.length))
    "#{first_word}-#{second_word}-#{SecureRandom.random_number(90) + 10}-#{SecureRandom.base58(12)}"
  end

  def password_setup
    mode = password_options_params[:password_mode].presence || 'temporary'
    return temporary_password_setup if mode == 'temporary'
    return password_mode_error('Modo de senha inválido.') unless PASSWORD_MODES.include?(mode)

    password = password_options_params[:password].to_s
    confirmation = password_options_params[:password_confirmation].to_s
    return password_mode_error(password_requirements_message) unless password_meets_requirements?(password)
    return password_mode_error('A confirmação da senha não confere.') unless password == confirmation

    { password: password, mode: mode, force_password_change: false }
  end

  def temporary_password_setup
    { password: temporary_password, mode: 'temporary', force_password_change: true }
  end

  def password_meets_requirements?(password)
    password.length >= 6 && password.match?(/[A-Z]/) && password.match?(/[a-z]/) && password.match?(/\d/) &&
      password.match?(/[!@#$%^&*()_+\-=\[\]{}|']/)
  end

  def password_requirements_message
    'Use pelo menos 6 caracteres, incluindo letra maiúscula, minúscula, número e símbolo especial.'
  end

  def password_mode_error(message)
    render json: { error: message }, status: :unprocessable_entity
    nil
  end

  def access_profile
    ACCESS_PROFILES.fetch(user_params[:access_profile])
  rescue KeyError
    raise ActionController::BadRequest, 'Perfil de acesso inválido.'
  end

  def duplicate_email_error
    render json: { error: 'Já existe uma conta com este e-mail.' }, status: :unprocessable_entity
  end

  def credentials_payload(user, password_setup)
    payload = { login: user.email, password_mode: password_setup[:mode] }
    payload[:temporary_password] = password_setup[:password] if password_setup[:mode] == 'temporary'
    payload
  end

  def user_payload(record)
    user = record.user
    {
      id: record.id,
      user_id: user.id,
      name: user.name,
      email: user.email,
      codusur: user.codusur,
      access_profile: profile_for(record, user),
      native_role: record.role,
      availability: record.availability,
      crm_role_id: OmnichannelCrm::RoleAssignment.find_by(account: current_account, user: user)&.role_id,
      team_ids: user.teams.where(account: current_account).ids,
      inbox_ids: user.inboxes.where(account: current_account).ids,
      supervised_team_ids: OmnichannelCrm::TeamSupervisor.where(account: current_account, user: user).pluck(:team_id)
    }
  end

  def profile_for(record, user)
    return 'administrator' if record.administrator?

    OmnichannelCrm::RoleAssignment.find_by(account: current_account, user: user)&.role&.key == 'supervisor' ? 'supervisor' : 'agent'
  end
end
