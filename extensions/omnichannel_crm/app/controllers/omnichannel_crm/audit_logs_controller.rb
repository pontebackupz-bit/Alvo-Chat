module OmnichannelCrm
  class AuditLogsController < ApplicationController
    before_action -> { authorize_crm!('audit.read') }

    def index
      logs = AuditLog.where(account: current_account).order(created_at: :desc).limit(params.fetch(:limit, 100))
      render json: logs
    end
  end
end
