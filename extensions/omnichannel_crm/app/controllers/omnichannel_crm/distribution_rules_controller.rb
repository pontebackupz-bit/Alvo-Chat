module OmnichannelCrm
  class DistributionRulesController < ApplicationController
    before_action -> { authorize_crm!('distribution.manage') }

    def index
      render json: DistributionRule.where(account: current_account).order(priority: :asc)
    end

    def show
      render json: find_rule
    end

    def create
      rule = DistributionRule.create!(rule_params.merge(account: current_account))
      audit!('distribution_rule.created', subject: rule)
      render json: rule, status: :created
    end

    def update
      rule = find_rule
      rule.update!(rule_params)
      audit!('distribution_rule.updated', subject: rule)
      render json: rule
    end

    def destroy
      rule = find_rule
      rule.destroy!
      audit!('distribution_rule.deleted', subject: rule)
      head :no_content
    end

    private

    def find_rule
      DistributionRule.where(account: current_account).find(params[:id])
    end

    def rule_params
      params.require(:distribution_rule).permit(:name, :strategy, :team_id, :priority, :active, conditions: {})
    end
  end
end
