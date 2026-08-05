module OmnichannelCrm
  class AutomationRulesController < ApplicationController
    before_action -> { authorize_crm!('automation.manage') }

    def index
      render json: AutomationRule.where(account: current_account).includes(:n8n_connection)
    end

    def show
      render json: find_rule
    end

    def create
      rule = AutomationRule.create!(rule_params.merge(account: current_account))
      audit!('automation_rule.created', subject: rule)
      render json: rule, status: :created
    end

    def update
      rule = find_rule
      rule.update!(rule_params)
      audit!('automation_rule.updated', subject: rule)
      render json: rule
    end

    def destroy
      rule = find_rule
      rule.destroy!
      audit!('automation_rule.deleted', subject: rule)
      head :no_content
    end

    private

    def find_rule
      AutomationRule.where(account: current_account).find(params[:id])
    end

    def rule_params
      params.require(:automation_rule).permit(:name, :event_name, :workflow_id, :webhook_path, :n8n_connection_id, :active, filters: {})
    end
  end
end
