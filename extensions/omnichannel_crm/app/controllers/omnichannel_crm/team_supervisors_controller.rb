module OmnichannelCrm
  class TeamSupervisorsController < ApplicationController
    before_action -> { authorize_crm!('teams.manage') }

    def index
      render json: TeamSupervisor.where(account: current_account)
    end

    def create
      supervisor = TeamSupervisor.create!(supervisor_params.merge(account: current_account))
      audit!('team_supervisor.created', subject: supervisor)
      render json: supervisor, status: :created
    end

    def destroy
      supervisor = TeamSupervisor.where(account: current_account).find(params[:id])
      supervisor.destroy!
      audit!('team_supervisor.deleted', subject: supervisor)
      head :no_content
    end

    private

    def supervisor_params
      params.require(:team_supervisor).permit(:team_id, :user_id)
    end
  end
end
