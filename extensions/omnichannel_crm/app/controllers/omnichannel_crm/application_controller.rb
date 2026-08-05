module OmnichannelCrm
  class ApplicationController < ::Api::V1::Accounts::BaseController
    private

    def authorize_crm!(permission)
      return if authorization.allows?(permission)

      render json: { error: 'You are not allowed to perform this CRM action' }, status: :forbidden
    end

    def authorization
      @authorization ||= Authorization.new(account: current_account, user: current_user)
    end

    def audit!(event_type, subject: nil, metadata: {})
      AuditLog.create!(account: current_account, actor: current_user, event_type: event_type,
                       subject_type: subject&.class&.name, subject_id: subject&.id, metadata: metadata)
    end
  end
end
