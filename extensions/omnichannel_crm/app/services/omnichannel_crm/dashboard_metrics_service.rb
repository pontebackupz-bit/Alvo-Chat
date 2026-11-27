# Commercial dashboard. Everything is limited to what the user can see:
# administrators the whole account, supervisors their teams, everyone else
# the teams they belong to (and their own work). `team_id` narrows it to one of the visible teams.
class OmnichannelCrm::DashboardMetricsService
  RESOLVED = ::Conversation.statuses.fetch('resolved')
  FIRST_RESPONSE_SQL = 'EXTRACT(EPOCH FROM conversations.first_reply_created_at - conversations.created_at)'.freeze

  def initialize(account:, authorization:, range:, team_id: nil)
    @account = account
    @authorization = authorization
    @range = range
    @team_id = team_id.presence&.to_i
  end

  def perform
    conversations = visible_conversations.where(created_at: @range)
    leads = visible_leads.where(created_at: @range)
    conversation_metrics(conversations).merge(lead_metrics(leads)).merge(
      sellers: seller_ranking(conversations, leads),
      teams: team_ranking(conversations),
      channels: inbox_volume(conversations),
      available_teams: @authorization.dashboard_teams.order(:name).map { |team| { id: team.id, name: team.name } },
      team_id: selected_team&.id
    )
  end

  private

  def selected_team
    return @selected_team if defined?(@selected_team)

    @selected_team = @team_id && @authorization.dashboard_teams.find_by(id: @team_id)
  end

  def visible_conversations
    scope = @authorization.dashboard_conversations
    selected_team ? scope.where(team_id: selected_team.id) : scope
  end

  def visible_leads
    scope = @authorization.dashboard_leads
    return scope unless selected_team

    scope.where(conversation_id: visible_conversations.select(:id)).or(scope.where(owner_id: selected_team.members.select(:id)))
  end

  # Unanswered and awaiting counts are about the conversations open now,
  # whatever the period.
  def conversation_metrics(conversations)
    {
      open_conversations: conversations.open.count,
      resolved_conversations: conversations.resolved.count,
      average_first_response_seconds: conversations.where.not(first_reply_created_at: nil).average(FIRST_RESPONSE_SQL)&.round(2),
      unanswered_conversations: backlog.where(first_reply_created_at: nil).count,
      awaiting_reply: backlog.where.not(waiting_since: nil).count,
      daily: conversations.group('DATE(conversations.created_at)').order('DATE(conversations.created_at)').count
    }
  end

  def lead_metrics(leads)
    { leads: leads.count, conversions: leads.stage_won.count, conversion_rate: conversion_rate(leads) }
  end

  def backlog
    visible_conversations.open
  end

  def conversion_rate(leads)
    total = leads.count
    return 0 if total.zero?

    (leads.stage_won.count.to_f / total * 100).round(2)
  end

  # Each seller is credited with the work they did in the period, whoever the
  # conversation is assigned to: conversations they answered, resolutions
  # they made and first replies they sent. Only "Abertas agora" is about the
  # assignment.
  def seller_ranking(conversations, leads)
    attended = attended_by_seller
    resolved = resolved_by_seller
    first_reply = first_reply_by_seller(conversations)
    open_now = open_by_seller
    won = conversions_by_seller(leads)
    ids = attended.keys | resolved.keys | open_now.keys | won.keys
    sellers = seller_names(ids).map do |id, name|
      { id: id, name: name, conversations: attended.fetch(id, 0), resolved: resolved.fetch(id, 0),
        average_first_response_seconds: first_reply[id], open: open_now.fetch(id, 0), conversions: won.fetch(id, 0) }
    end
    sellers.sort_by { |seller| [-seller[:resolved], -seller[:conversations], -seller[:conversions], seller[:name].to_s] }
  end

  # Conversations in which the seller sent at least one reply in the period.
  def attended_by_seller
    ::Message.outgoing.where(private: false, sender_type: 'User', created_at: @range,
                             conversation_id: visible_conversations.select(:id))
             .reorder(nil).group(:sender_id).distinct.count(:conversation_id)
  end

  def resolved_by_seller
    messages = OmnichannelCrm::ResolutionAuthor.messages(visible_conversations).where(created_at: @range)
    OmnichannelCrm::ResolutionAuthor.counts(messages, @account.users.pluck(:id, :name))
  end

  # First reply time of the conversations started in the period, credited to
  # whoever sent that first reply.
  def first_reply_by_seller(conversations)
    conversations.where.not(first_reply_created_at: nil)
                 .joins('INNER JOIN messages first_replies ON first_replies.conversation_id = conversations.id ' \
                        'AND first_replies.created_at = conversations.first_reply_created_at')
                 .where(first_replies: { sender_type: 'User', message_type: ::Message.message_types[:outgoing] })
                 .group('first_replies.sender_id').average(FIRST_RESPONSE_SQL)
                 .transform_values { |average| average&.to_f&.round(2) }
  end

  def open_by_seller
    backlog.where.not(assignee_id: nil).group(:assignee_id).count
  end

  def conversions_by_seller(leads)
    leads.stage_won.where.not(owner_id: nil).group(:owner_id).count
  end

  # Administrators manage the account and are not ranked as sellers, even
  # when a conversation is assigned to them.
  def seller_names(ids)
    @account.users.where(id: ids).where.not(id: @account.account_users.administrator.select(:user_id)).pluck(:id, :name)
  end

  def team_ranking(conversations)
    rows = conversations.group(:team_id).pluck(:team_id, Arel.sql('COUNT(*)'),
                                               Arel.sql("COUNT(*) FILTER (WHERE conversations.status = #{RESOLVED})"))
    names = @account.teams.where(id: rows.filter_map(&:first)).pluck(:id, :name).to_h
    rows.map { |id, total, resolved| { id: id, name: names[id], conversations: total, resolved: resolved } }
        .sort_by { |team| -team[:conversations] }
  end

  def inbox_volume(conversations)
    conversations.joins(:inbox).group('inboxes.name').order('count_all DESC').count
  end
end
