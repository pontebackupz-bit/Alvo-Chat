# Runs waiting for a human attendance to end are active too.
class AddWaitingAgentToCrmWorkflowRuns < ActiveRecord::Migration[7.1]
  INDEX = 'index_crm_workflow_runs_active_by_conversation'.freeze

  def up
    remove_index :crm_workflow_runs, name: INDEX
    add_index :crm_workflow_runs, :conversation_id, unique: true, name: INDEX,
                                                    where: "status IN ('running', 'waiting_reply', 'waiting_delay', 'waiting_agent')"
  end

  def down
    remove_index :crm_workflow_runs, name: INDEX
    add_index :crm_workflow_runs, :conversation_id, unique: true, name: INDEX,
                                                    where: "status IN ('running', 'waiting_reply', 'waiting_delay')"
  end
end
