# Administrators see every conversation but never receive one automatically:
# Chatwoot's auto assignment (round robin, v1 and v2), the CRM distribution
# rules and the number owner in Conexões all skip them. They can still take
# or be given a conversation by hand.
module OmnichannelCrm::AdministratorsNotAutoAssigned
  def self.administrator_ids(account_id)
    ::AccountUser.where(account_id: account_id).administrator.pluck(:user_id)
  end

  def self.administrator?(user, account_id)
    user.present? && ::AccountUser.where(account_id: account_id, user_id: user.id).administrator.exists?
  end

  # Auto assignment v1 (AutoAssignment::AgentAssignmentService), also used
  # when a conversation gets a team.
  module AgentAssignment
    private

    def allowed_online_agent_ids
      ids = super
      return ids if ids.blank?

      ids - OmnichannelCrm::AdministratorsNotAutoAssigned.administrator_ids(conversation.account_id).map(&:to_s)
    end
  end

  # Auto assignment v2 (AutoAssignment::AssignmentService); `agents` are inbox members.
  module AssignmentV2
    private

    def filter_agents_by_team(agents, conversation)
      agents = super
      return agents if agents.nil?

      agents.where.not(user_id: OmnichannelCrm::AdministratorsNotAutoAssigned.administrator_ids(inbox.account_id))
    end
  end
end
