class OmnichannelCrm::PasswordChangesController < Api::BaseController
  skip_before_action :enforce_forced_password_change!

  def create
    password = password_params[:password]

    if current_user.valid_password?(password)
      return render json: { error: 'A nova senha deve ser diferente da senha temporária.' }, status: :unprocessable_entity
    end

    current_user.update!(
      password: password,
      password_confirmation: password_params[:password_confirmation],
      force_password_change: false
    )

    render json: { success: true }
  end

  private

  def password_params
    params.require(:password_change).permit(:password, :password_confirmation)
  end
end
