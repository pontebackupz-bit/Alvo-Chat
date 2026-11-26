module OmnichannelCrm
  class Authorization
    def initialize(account:, user:)
      @account = account
      @user = user
    end

    def allows?(permission)
      return true if account_administrator?

      permission_keys.include?('*') || permission_keys.include?(permission)
    end

    def seller?
      role&.key == 'seller'
    end

    def supervisor?
      role&.key == 'supervisor'
    end

    def agent?
      role&.key == 'agent'
    end

    def visible_conversations
      scope = ::Conversation.where(account: @account)
      return scope if account_administrator?
      return scope.where(team_id: supervised_team_ids) if supervisor?

      scope.where(assignee_id: @user.id)
    end

    # Supervisors see the leads of their teams' conversations and of their
    # teams' sellers; sellers see their own leads.
    def visible_leads
      scope = Lead.where(account: @account)
      return scope if account_administrator?
      return scope.where(owner_id: @user.id) unless supervisor?

      member_ids = ::TeamMember.where(team_id: supervised_team_ids).select(:user_id)
      scope.where(conversation_id: visible_conversations.select(:id)).or(scope.where(owner_id: member_ids))
    end

    def visible_teams
      return @account.teams if account_administrator?
      return @account.teams.where(id: supervised_team_ids) if supervisor?

      @account.teams.none
    end

    # Painel comercial: open to every member. Administrators and supervisors
    # see what they already see; everyone else sees the teams they belong to,
    # plus the conversations and leads that are theirs.
    def dashboard_teams
      return visible_teams if full_dashboard?

      @account.teams.where(id: member_team_ids)
    end

    def dashboard_conversations
      return visible_conversations if full_dashboard?

      scope = ::Conversation.where(account: @account)
      scope.where(team_id: member_team_ids).or(scope.where(assignee_id: @user.id))
    end

    def dashboard_leads
      return visible_leads if full_dashboard?

      scope = Lead.where(account: @account)
      member_ids = ::TeamMember.where(team_id: member_team_ids).select(:user_id)
      scope.where(conversation_id: dashboard_conversations.select(:id)).or(scope.where(owner_id: member_ids))
           .or(scope.where(owner_id: @user.id))
    end

    def supervised_team_ids
      TeamSupervisor.where(account: @account, user: @user).select(:team_id)
    end

    private

    def full_dashboard?
      account_administrator? || supervisor?
    end

    def member_team_ids
      ::TeamMember.where(user: @user).joins(:team).where(teams: { account_id: @account.id }).select(:team_id)
    end

    def account_administrator?
      @account.account_users.find_by(user: @user)&.administrator?
    end

    def role
      @role ||= RoleAssignment.includes(role: :permissions).find_by(account: @account, user: @user)&.role
    end

    def permission_keys
      role&.permission_keys || []
    end
  end
end
