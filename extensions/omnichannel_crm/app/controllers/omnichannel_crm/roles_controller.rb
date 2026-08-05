module OmnichannelCrm
  class RolesController < ApplicationController
    before_action -> { authorize_crm!('settings.manage') }

    def index
      render json: Role.where(account: current_account).includes(:permissions)
    end

    def create
      role = Role.create!(role_params.merge(account: current_account))
      replace_permissions(role)
      audit!('role.created', subject: role)
      render json: role, status: :created
    end

    def update
      role = Role.where(account: current_account).find(params[:id])
      role.update!(role_params)
      replace_permissions(role)
      audit!('role.updated', subject: role)
      render json: role
    end

    private

    def role_params
      params.require(:role).permit(:name, :key)
    end

    def replace_permissions(role)
      return unless params[:permission_keys]

      role.permissions = Permission.where(key: params[:permission_keys])
    end
  end
end
