class DeviseOverrides::PasswordsController < Devise::PasswordsController
  skip_before_action :require_no_authentication, raise: false
  skip_before_action :authenticate_user!, raise: false

  def create
    build_response(I18n.t('messages.password_reset_admin_only'), :forbidden)
  end

  def update
    build_response(I18n.t('messages.password_reset_admin_only'), :forbidden)
  end

  private

  def build_response(message, status)
    render json: {
      message: message
    }, status: status
  end
end

DeviseOverrides::PasswordsController.prepend_mod_with('DeviseOverrides::PasswordsController')
