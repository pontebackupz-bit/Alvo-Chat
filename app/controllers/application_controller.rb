class ApplicationController < ActionController::Base
  include DeviseTokenAuth::Concerns::SetUserByToken
  include RequestExceptionHandler
  include Pundit::Authorization
  include SwitchLocale
  include TrackSessionActivity

  skip_before_action :verify_authenticity_token

  before_action :set_current_user, unless: :devise_controller?
  before_action :enforce_forced_password_change!, unless: :devise_controller?
  around_action :switch_locale
  around_action :handle_with_exception, unless: :devise_controller?

  private

  def set_current_user
    @user ||= current_user
    Current.user = @user
  end

  def enforce_forced_password_change!
    return unless current_user&.force_password_change?

    render json: {
      error: 'É necessário definir uma nova senha antes de continuar.',
      code: 'password_change_required'
    }, status: :forbidden
  end

  def pundit_user
    {
      user: Current.user,
      account: Current.account,
      account_user: Current.account_user
    }
  end
end
ApplicationController.include_mod_with('Concerns::ApplicationControllerConcern')
