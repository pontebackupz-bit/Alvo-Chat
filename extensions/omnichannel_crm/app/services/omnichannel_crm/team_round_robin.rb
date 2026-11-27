# Picks the next seller of a team in turn. Supervisors of the team never get
# conversations; online members are preferred, and when nobody is online the
# turn still moves across every seller so no conversation is left unowned.
# The turn is the member who received a conversation of the team longest ago,
# taken from the `conversation.distributed` audit trail.
class OmnichannelCrm::TeamRoundRobin
  EVENT = 'conversation.distributed'.freeze

  def initialize(team)
    @team = team
  end

  # Moves the conversation to the team. Unless `distribute` is false, it also
  # goes to the next seller in turn when no member of the team has it yet.
  def transfer(conversation, distribute: true)
    return conversation.update!(team: team) if distribute.to_s == 'false' || team.members.exists?(id: conversation.assignee_id)

    assign(conversation)
  end

  def assign(conversation)
    team.with_lock do
      agent = next_agent
      conversation.update!(team: team, assignee: agent)
      record(conversation, agent) if agent
      agent
    end
  end

  private

  attr_reader :team

  def next_agent
    pool = online_first(candidates)
    return if pool.empty?

    last_turns = last_assignment_times(pool.map(&:id))
    pool.min_by { |seller| [last_turns[seller.id] || Time.zone.at(0), seller.id] }
  end

  def online_first(sellers)
    online_ids = team.account.account_users.where(user_id: sellers.map(&:id), availability: :online).pluck(:user_id)
    sellers.select { |seller| online_ids.include?(seller.id) }.presence || sellers
  end

  def candidates
    supervisor_ids = OmnichannelCrm::TeamSupervisor.where(team_id: team.id).pluck(:user_id)
    team.members.where.not(id: supervisor_ids).order(:id).to_a
  end

  def last_assignment_times(user_ids)
    OmnichannelCrm::AuditLog.where(account_id: team.account_id, event_type: EVENT)
                            .where("metadata ->> 'team_id' = ?", team.id.to_s)
                            .where("(metadata ->> 'assignee_id')::bigint IN (?)", user_ids)
                            .group(Arel.sql("(metadata ->> 'assignee_id')::bigint"))
                            .maximum(:created_at)
  end

  def record(conversation, agent)
    OmnichannelCrm::AuditLog.create!(account_id: team.account_id, event_type: EVENT, subject_type: 'Conversation',
                                     subject_id: conversation.id,
                                     metadata: { team_id: team.id, assignee_id: agent.id, source: 'round_robin' })
  end
end
