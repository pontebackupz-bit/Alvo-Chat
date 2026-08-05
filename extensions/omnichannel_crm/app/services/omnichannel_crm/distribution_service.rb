module OmnichannelCrm
  class DistributionService
    def initialize(conversation)
      @conversation = conversation
    end

    def perform
      return unless @conversation.open? && @conversation.assignee_id.nil?

      matching_rule&.with_lock { |rule| assign(rule) }
    end

    private

    def matching_rule
      DistributionRule.where(account: @conversation.account, active: true).order(:priority).find do |rule|
        conditions_match?(rule.conditions)
      end
    end

    def conditions_match?(conditions)
      return true if conditions.blank?

      conditions.all? do |key, value|
        case key.to_s
        when 'channel' then @conversation.inbox.channel_type == value
        when 'inbox_id' then @conversation.inbox_id == value
        when 'tag' then @conversation.cached_label_list_array.include?(value)
        when 'origin' then @conversation.additional_attributes['referer'] == value
        else false
        end
      end
    end

    def assign(rule)
      agent = select_agent(rule)
      return unless agent

      @conversation.update!(team: rule.team) if rule.team && @conversation.team != rule.team
      @conversation.update!(assignee: agent)
      rule.update!(last_assignee_id: agent.id) if rule.round_robin?
      AuditLog.create!(account: @conversation.account, event_type: 'conversation.distributed', subject_type: 'Conversation',
                       subject_id: @conversation.id, metadata: { rule_id: rule.id, assignee_id: agent.id, team_id: rule.team_id })
    end

    def select_agent(rule)
      agents = candidates(rule)
      return if agents.empty?

      return least_open_conversations(agents) if rule.least_open_conversations?

      agents.find { |agent| agent.id > rule.last_assignee_id.to_i } || agents.first
    end

    def candidates(rule)
      user_ids = rule.team ? rule.team.members.ids : @conversation.account.users.ids
      @conversation.account.account_users.where(user_id: user_ids, availability: :online).includes(:user).map(&:user).sort_by(&:id)
    end

    def least_open_conversations(agents)
      agents.min_by { |agent| @conversation.account.conversations.open.where(assignee: agent).count }
    end
  end
end
