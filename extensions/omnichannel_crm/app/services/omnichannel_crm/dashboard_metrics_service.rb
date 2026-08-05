module OmnichannelCrm
  class DashboardMetricsService
    def initialize(account:, authorization:, range:)
      @account = account
      @authorization = authorization
      @range = range
    end

    def perform
      conversations = @authorization.visible_conversations.where(created_at: @range)
      leads = Lead.where(account: @account, created_at: @range)
      {
        leads: leads.count,
        open_conversations: conversations.open.count,
        resolved_conversations: conversations.resolved.count,
        conversions: leads.stage_won.count,
        conversion_rate: conversion_rate(leads),
        average_first_response_seconds: average_first_response(conversations),
        sellers: seller_ranking(leads),
        teams: team_ranking(conversations),
        channels: channel_volume(conversations),
        daily: conversations.group('DATE(conversations.created_at)').order('DATE(conversations.created_at)').count
      }
    end

    private

    def conversion_rate(leads)
      return 0 if leads.count.zero?

      (leads.stage_won.count.to_f / leads.count * 100).round(2)
    end

    def average_first_response(conversations)
      conversations.where.not(first_reply_created_at: nil).average('EXTRACT(EPOCH FROM first_reply_created_at - created_at)')&.round(2)
    end

    def seller_ranking(leads)
      leads.group(:owner_id).order('count_all DESC').limit(10).count
    end

    def team_ranking(conversations)
      conversations.group(:team_id).order('count_all DESC').limit(10).count
    end

    def channel_volume(conversations)
      conversations.joins(:inbox).group('inboxes.channel_type').count
    end
  end
end
