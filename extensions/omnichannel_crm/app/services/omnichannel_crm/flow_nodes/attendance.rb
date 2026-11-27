# Blocks that hand the conversation to people.
module OmnichannelCrm::FlowNodes::Attendance
  private

  # Moves the conversation to a team (chosen, or found by the department
  # name of an imported flow). With `wait_for_agent` the flow pauses until
  # the conversation is resolved and then continues through `next`.
  def execute_transfer_team(data)
    team = flow_team(data)
    return 'error' unless team

    keep = flow_assignee_for?(team) ? { distribute: false } : { distribute: data['distribute'] }
    OmnichannelCrm::TeamRoundRobin.new(team).transfer(conversation, **keep)
    ActiveModel::Type::Boolean.new.cast(data['wait_for_agent']) ? :wait_agent : 'next'
  end

  # Assigns a person (chosen, or found by e-mail). With `only_if_online` an
  # offline person is skipped; `input.online` tells the next blocks.
  def execute_assign_agent(data)
    agent = flow_agent(data)
    online = agent.present? && (!ActiveModel::Type::Boolean.new.cast(data['only_if_online']) || online?(agent))
    if online
      team = flow_team(data)
      attributes = { assignee: agent }
      attributes[:team] = team if team&.members&.exists?(id: agent.id)
      conversation.update!(attributes)
      remember('__flow_assignee_id' => agent.id)
    end
    remember('input' => { 'online' => online, 'agent' => agent && { 'name' => agent.name, 'email' => agent.email } })
    'next'
  end

  # After the attendance, `input` describes it like EZ.Chat does.
  def resume_after_attendance
    assignee = conversation.assignee
    remember('input' => {
               'agents' => assignee ? [{ 'agent' => { 'name' => assignee.name, 'email' => assignee.email } }] : [],
               'departments' => conversation.team ? [{ 'name' => conversation.team.name }] : [],
               'classifications' => conversation.label_list.map { |label| { 'name' => label } }
             })
    move_to(next_node_id(current_node, 'next'))
  end

  def flow_team(data)
    teams = conversation.account.teams
    return teams.find_by(id: data['team_id']) if data['team_id'].present?

    wanted = comparable_name(data['team_name'])
    wanted.present? ? teams.find { |team| comparable_name(team.name) == wanted } : nil
  end

  def flow_agent(data)
    users = conversation.account.users
    return users.find_by(id: data['agent_id']) if data['agent_id'].present?

    email = template.render(data['agent_email'].to_s).strip.downcase
    return if email.blank? || email == '0'

    users.find_by('LOWER(users.email) = ?', email) ||
      (users.find_by('LOWER(users.email) LIKE ?', "#{ActiveRecord::Base.sanitize_sql_like(email)}@%") unless email.include?('@'))
  end

  # A person picked earlier in the flow keeps the conversation when it is
  # then moved to their team.
  def flow_assignee_for?(team)
    assignee_id = run.variables['__flow_assignee_id']
    assignee_id.present? && conversation.assignee_id == assignee_id && team.members.exists?(id: assignee_id)
  end

  def online?(agent)
    OnlineStatusTracker.get_available_users(conversation.account_id).transform_keys(&:to_s)[agent.id.to_s] == 'online'
  end

  def comparable_name(name)
    ActiveSupport::Inflector.transliterate(name.to_s).downcase.gsub(/[^a-z0-9]+/, ' ').strip
  end
end
