# Limits supervisors to the conversations of the teams they supervise.
module OmnichannelCrm::SupervisorConversationScope
  module Finder
    private

    # The regular filter keeps only inboxes the user belongs to; supervisors are
    # limited by team instead.
    def find_all_conversations
      team_ids = current_user.supervised_team_ids_for(current_account)
      return super if team_ids.blank?

      find_conversation_by_inbox
      @conversations = @conversations.joins(:contact, :inbox).where(team_id: team_ids)
      filter_by_conversation_type if params[:conversation_type]
      @conversations
    end
  end

  module Policy
    def show?
      team_ids = user.respond_to?(:supervised_team_ids_for) ? user.supervised_team_ids_for(account) : []
      return team_ids.include?(record.team_id) if team_ids.present? && !administrator?

      super
    end
  end
end
