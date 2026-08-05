module OmnichannelCrm
  class DashboardsController < ApplicationController
    before_action -> { authorize_crm!('dashboards.read') }

    def show
      render json: DashboardMetricsService.new(account: current_account, authorization: authorization,
                                               range: date_range).perform
    end

    private

    def date_range
      start_at = params[:start_at].present? ? Time.zone.parse(params[:start_at]) : 30.days.ago
      end_at = params[:end_at].present? ? Time.zone.parse(params[:end_at]) : Time.current
      start_at..end_at
    end
  end
end
