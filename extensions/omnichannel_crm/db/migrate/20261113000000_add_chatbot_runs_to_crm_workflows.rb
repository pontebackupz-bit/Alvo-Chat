class AddChatbotRunsToCrmWorkflows < ActiveRecord::Migration[7.1]
  def change
    add_column :crm_workflows, :active, :boolean, null: false, default: false
    add_column :crm_workflows, :trigger_config, :jsonb, null: false, default: {}
    add_index :crm_workflows, [:account_id, :active]

    create_table :crm_workflow_runs do |t|
      t.bigint :account_id, null: false
      t.bigint :workflow_id, null: false
      t.bigint :conversation_id, null: false
      t.string :current_node_id
      t.string :status, null: false, default: 'running'
      t.jsonb :variables, null: false, default: {}
      t.datetime :waiting_since
      t.text :error_message
      t.timestamps
    end

    add_index :crm_workflow_runs, :workflow_id
    # A conversation runs at most one flow at a time.
    add_index :crm_workflow_runs, :conversation_id, unique: true,
                                                    where: "status IN ('running', 'waiting_reply', 'waiting_delay')",
                                                    name: 'index_crm_workflow_runs_active_by_conversation'
  end
end
