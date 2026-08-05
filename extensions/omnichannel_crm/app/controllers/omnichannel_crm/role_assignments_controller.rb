module OmnichannelCrm
  class RoleAssignmentsController < ApplicationController
    before_action -> { authorize_crm!('users.manage') }

    def index
      render json: RoleAssignment.where(account: current_account).includes(:role, :user)
    end

    def create
      assignment = RoleAssignment.create!(assignment_params.merge(account: current_account))
      audit!('role_assignment.created', subject: assignment)
      render json: assignment, status: :created
    end

    def destroy
      assignment = RoleAssignment.where(account: current_account).find(params[:id])
      assignment.destroy!
      audit!('role_assignment.deleted', subject: assignment)
      head :no_content
    end

    private

    def assignment_params
      params.require(:role_assignment).permit(:user_id, :role_id)
    end
  end
end
