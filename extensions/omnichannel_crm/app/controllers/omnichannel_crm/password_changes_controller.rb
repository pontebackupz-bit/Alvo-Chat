class OmnichannelCrm::PasswordChangesController < Api::BaseController
  skip_before_action :enforce_forced_password_change!

  def create
    password = password_params[:password]

    unless password_meets_requirements?(password)
      return render json: { error: password_requirements_message }, status: :unprocessable_entity
    end

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

  def password_meets_requirements?(password)
    password.to_s.length >= 6 &&
      password.match?(/[A-Z]/) &&
      password.match?(/[a-z]/) &&
      password.match?(/\d/) &&
      password.match?(/[!@#$%^&*()_+\-=\[\]{}|']/)
  end

  def password_requirements_message
    'Use pelo menos 6 caracteres, incluindo letra maiúscula, minúscula, número e símbolo especial.'
  end
end
