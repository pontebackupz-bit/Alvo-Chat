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

    def visible_conversations
      scope = ::Conversation.where(account: @account)
      return scope if account_administrator?
      return scope.where(team_id: supervised_team_ids) if supervisor?

      scope.where(assignee_id: @user.id)
    end

    def supervised_team_ids
      TeamSupervisor.where(account: @account, user: @user).select(:team_id)
    end

    private

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
