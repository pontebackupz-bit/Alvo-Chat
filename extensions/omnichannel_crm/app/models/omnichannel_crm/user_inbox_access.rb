# Supervisors see the numbers (inboxes) and conversations of the teams they
# supervise without being added as inbox members. Administrators already see
# everything. Other roles keep Chatwoot's regular inbox membership rules.
module OmnichannelCrm::UserInboxAccess
  def assigned_inboxes
    team_ids = supervised_team_ids_for(Current.account)
    return super if team_ids.blank?

    account = Current.account
    by_team = account.inboxes.where(id: ::Conversation.where(account_id: account.id, team_id: team_ids).select(:inbox_id))
    by_default_team = account.inboxes.where(channel_type: 'Channel::Api', channel_id: default_team_channel_ids(team_ids))
    account.inboxes.where(id: super.select(:id)).or(by_team).or(by_default_team)
  end

  # Team ids supervised in the account; empty unless the user is a supervisor.
  def supervised_team_ids_for(account)
    return [] unless account

    authorization = OmnichannelCrm::Authorization.new(account: account, user: self)
    authorization.supervisor? ? authorization.supervised_team_ids.pluck(:team_id) : []
  end

  private

  def default_team_channel_ids(team_ids)
    Channel::Api.where("(additional_attributes ->> 'default_team_id')::int IN (?)", team_ids).select(:id)
  end
end
