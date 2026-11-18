# How a chatbot flow performs: runs started in the period and how they ended.
# A run still waiting for the customer after ABANDON_AFTER counts as abandoned
# at the block it stopped on, which is where customers give up.
class OmnichannelCrm::WorkflowMetricsService
  ABANDON_AFTER = 24.hours
  PREVIEW_LENGTH = 80

  def initialize(workflow:, range:)
    @workflow = workflow
    @range = range
  end

  def perform
    statuses = runs.group(:status).count
    abandoned = abandoned_runs.count
    started = statuses.values.sum
    {
      started: started,
      completed: statuses.fetch('completed', 0),
      handed_over: statuses.fetch('cancelled', 0),
      failed: statuses.fetch('failed', 0),
      abandoned: abandoned,
      in_progress: OmnichannelCrm::WorkflowRun::ACTIVE_STATUSES.sum { |status| statuses.fetch(status, 0) } - abandoned,
      completion_rate: started.zero? ? 0 : (statuses.fetch('completed', 0) * 100.0 / started).round(1),
      drop_off: drop_off
    }
  end

  private

  attr_reader :workflow, :range

  def runs
    workflow.runs.where(created_at: range)
  end

  def abandoned_runs
    runs.where(status: :waiting_reply).where(waiting_since: ...ABANDON_AFTER.ago)
  end

  def drop_off
    nodes = workflow.nodes.index_by { |node| node['id'] }
    abandoned_runs.group(:current_node_id).count.sort_by { |_id, count| -count }.map do |node_id, count|
      node = nodes[node_id] || {}
      data = node['data'] || {}
      { node_id: node_id, type: node['type'], title: data['title'].presence,
        preview: data['content'].to_s.squish.truncate(PREVIEW_LENGTH).presence, count: count }
    end
  end
end
