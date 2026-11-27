# Supervisors see every conversation of the teams they supervise (and only
# those), without being members of the inboxes. Administrators see everything.
module OmnichannelCrm::SupervisorConversationScope
  # Supervised team ids, or [] when the user is not scoped as a supervisor.
  def self.team_ids_for(user, account)
    return [] unless user.respond_to?(:supervised_team_ids_for) && account
    return [] if account.account_users.find_by(user_id: user.id)&.administrator?

    user.supervised_team_ids_for(account)
  end

  # Conversations::PermissionFilterService backs the conversation list, the
  # advanced filters, bulk actions and the unread counters.
  module PermissionFilter
    def perform
      team_ids = OmnichannelCrm::SupervisorConversationScope.team_ids_for(user, account)
      return super if team_ids.blank?

      conversations.where(team_id: team_ids)
    end
  end

  module Policy
    def show?
      team_ids = OmnichannelCrm::SupervisorConversationScope.team_ids_for(user, account)
      return team_ids.include?(record.team_id) if team_ids.present?

      super
    end
  end

  # Global search: conversations and messages.
  module Search
    private

    def filter_conversations
      return super if supervised_team_ids.blank?

      @conversations = super.where(conversations: { team_id: supervised_team_ids })
    end

    def message_base_query
      return super if supervised_team_ids.blank?

      super.where(conversation_id: current_account.conversations.where(team_id: supervised_team_ids).select(:id))
    end

    # Elasticsearch (enterprise advanced search).
    def build_where_conditions
      conditions = super
      return conditions if supervised_team_ids.blank?

      conditions.merge(conversation_id: current_account.conversations.where(team_id: supervised_team_ids).pluck(:id))
    end

    def supervised_team_ids
      @supervised_team_ids ||= OmnichannelCrm::SupervisorConversationScope.team_ids_for(current_user, current_account)
    end
  end
end
