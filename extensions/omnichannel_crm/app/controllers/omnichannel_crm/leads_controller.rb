module OmnichannelCrm
  class LeadsController < ApplicationController
    before_action -> { authorize_crm!('leads.manage') }, only: [:create, :update, :convert]
    before_action -> { authorize_crm!('leads.read') }, only: [:index, :show]

    def index
      leads = Lead.where(account: current_account).order(created_at: :desc)
      render json: leads.where(id: visible_lead_ids)
    end

    def show
      render json: find_lead
    end

    def create
      lead = Lead.create!(lead_params.merge(account: current_account, owner: current_user))
      audit!('lead.created', subject: lead)
      render json: lead, status: :created
    end

    def update
      lead = find_lead
      lead.update!(lead_params)
      audit!('lead.updated', subject: lead)
      render json: lead
    end

    def convert
      lead = find_lead
      lead.stage_won!
      EventFanoutService.new(event_name: 'lead.converted', account: current_account,
                             payload: { lead_id: lead.id, contact_id: lead.contact_id }).perform
      audit!('lead.converted', subject: lead)
      render json: lead
    end

    private

    def find_lead
      Lead.where(account: current_account).find(params[:id])
    end

    def visible_lead_ids
      return Lead.where(account: current_account).select(:id) unless authorization.seller?

      Lead.where(account: current_account, owner: current_user).select(:id)
    end

    def lead_params
      params.require(:lead).permit(:contact_id, :conversation_id, :owner_id, :stage, :source, :value, metadata: {})
    end
  end
end
