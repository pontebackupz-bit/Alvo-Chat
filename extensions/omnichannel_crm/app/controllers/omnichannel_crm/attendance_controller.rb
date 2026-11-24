# Attendance screen data, limited to the conversations the user can see
# (administrators: all; supervisors: their teams; agents: their inboxes).
class OmnichannelCrm::AttendanceController < OmnichannelCrm::ApplicationController
  HISTORY_PAGE_SIZE = 25
  ONLINE_STATUSES = %w[online busy].freeze

  # Counters above the conversation list.
  def stats
    open_conversations = visible.where(status: :open)
    render json: {
      resolved_today: resolved_today,
      agents_online: agents_online,
      late: OmnichannelCrm::AttendanceFilters.waiting_over(visible, late_after).count,
      active: open_conversations.count,
      snoozed: visible.where(status: :snoozed).count,
      late_after_minutes: late_after
    }
  end

  # "Histórico de chats": finished conversations, newest first.
  def history
    scope = history_scope
    page = [params[:page].to_i, 1].max
    total = scope.count
    rows = scope.order(last_activity_at: :desc).offset((page - 1) * HISTORY_PAGE_SIZE).limit(HISTORY_PAGE_SIZE)
                .includes(:contact, :assignee, :team, :inbox)
    render json: { conversations: rows.map { |conversation| history_row(conversation) }, total: total,
                   page: page, page_size: HISTORY_PAGE_SIZE }
  end

  private

  def visible
    @visible ||= Conversations::PermissionFilterService.new(
      current_account.conversations.joins(:contact, :inbox), current_user, current_account
    ).perform
  end

  def late_after
    OmnichannelCrm::AttendanceFilters::LATE_AFTER_MINUTES
  end

  def resolved_today
    ReportingEvent.where(account_id: current_account.id, name: 'conversation_resolved', created_at: Time.zone.today.all_day,
                         conversation_id: visible.select(:id))
                  .distinct.count(:conversation_id)
  end

  def agents_online
    OnlineStatusTracker.get_available_users(current_account.id).count { |_id, status| ONLINE_STATUSES.include?(status.to_s) }
  end

  def history_scope
    scope = visible.where(status: :resolved)
    scope = OmnichannelCrm::AttendanceFilters.search(scope, params[:search]) if params[:search].present?
    scope = scope.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    scope = scope.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    scope = scope.where(last_activity_at: Time.zone.parse(params[:since]).beginning_of_day..) if params[:since].present?
    scope = scope.where(last_activity_at: ..Time.zone.parse(params[:until]).end_of_day) if params[:until].present?
    scope
  end

  def history_row(conversation)
    contact = conversation.contact
    {
      id: conversation.display_id, contact: { name: contact&.name, phone: contact&.phone_number },
      assignee: conversation.assignee&.name, team: conversation.team&.name, inbox: conversation.inbox&.name,
      group: OmnichannelCrm::WhatsappGroup.conversation?(conversation),
      created_at: conversation.created_at, last_activity_at: conversation.last_activity_at
    }
  end
end
