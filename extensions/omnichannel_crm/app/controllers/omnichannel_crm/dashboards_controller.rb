module OmnichannelCrm
  class DashboardsController < ApplicationController
    # Every member of the account can open the Painel comercial; what each one
    # sees is limited by Authorization#dashboard_conversations.

    def show
      render json: DashboardMetricsService.new(account: current_account, authorization: authorization,
                                               range: date_range, team_id: params[:team_id]).perform
    end

    private

    def date_range
      start_at = params[:start_at].present? ? Time.zone.parse(params[:start_at]) : 30.days.ago
      end_at = params[:end_at].present? ? Time.zone.parse(params[:end_at]) : Time.current
      start_at..end_at
    end
  end
end
