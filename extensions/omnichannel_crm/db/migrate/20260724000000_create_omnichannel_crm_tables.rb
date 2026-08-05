class CreateOmnichannelCrmTables < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_roles do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.string :key, null: false
      t.timestamps
    end
    add_index :crm_roles, [:account_id, :key], unique: true

    create_table :crm_permissions do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :crm_permissions, :key, unique: true

    create_table :crm_role_permissions do |t|
      t.references :role, null: false, index: false
      t.references :permission, null: false, index: false
      t.timestamps
    end
    add_index :crm_role_permissions, [:role_id, :permission_id], unique: true

    create_table :crm_role_assignments do |t|
      t.bigint :account_id, null: false
      t.bigint :user_id, null: false
      t.references :role, null: false, index: true
      t.timestamps
    end
    add_index :crm_role_assignments, [:account_id, :user_id], unique: true

    create_table :crm_team_supervisors do |t|
      t.bigint :account_id, null: false
      t.bigint :team_id, null: false
      t.bigint :user_id, null: false
      t.timestamps
    end
    add_index :crm_team_supervisors, [:team_id, :user_id], unique: true

    create_table :crm_leads do |t|
      t.bigint :account_id, null: false
      t.bigint :contact_id, null: false
      t.bigint :conversation_id
      t.bigint :owner_id
      t.integer :stage, null: false, default: 0
      t.string :source
      t.decimal :value, precision: 14, scale: 2
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :crm_leads, [:account_id, :contact_id], unique: true
    add_index :crm_leads, [:account_id, :stage]

    create_table :crm_n8n_connections do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.string :base_url, null: false
      t.text :api_key, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :crm_n8n_connections, [:account_id, :name], unique: true

    create_table :crm_automation_rules do |t|
      t.bigint :account_id, null: false
      t.bigint :n8n_connection_id, null: false
      t.string :name, null: false
      t.string :event_name, null: false
      t.string :workflow_id, null: false
      t.string :webhook_path, null: false
      t.jsonb :filters, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :crm_automation_rules, [:account_id, :event_name]

    create_table :crm_workflow_executions do |t|
      t.bigint :account_id, null: false
      t.bigint :n8n_connection_id, null: false
      t.bigint :automation_rule_id
      t.string :workflow_id, null: false
      t.string :webhook_path, null: false
      t.string :trigger, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :request_payload, null: false, default: {}
      t.jsonb :response_payload
      t.text :error_message
      t.datetime :completed_at
      t.timestamps
    end
    add_index :crm_workflow_executions, [:account_id, :created_at]
    add_index :crm_workflow_executions, [:n8n_connection_id, :status]

    create_table :crm_distribution_rules do |t|
      t.bigint :account_id, null: false
      t.bigint :team_id
      t.string :name, null: false
      t.integer :strategy, null: false, default: 0
      t.integer :priority, null: false, default: 100
      t.bigint :last_assignee_id
      t.jsonb :conditions, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :crm_distribution_rules, [:account_id, :priority]

    create_table :crm_audit_logs do |t|
      t.bigint :account_id, null: false
      t.bigint :actor_id
      t.string :event_type, null: false
      t.string :subject_type
      t.bigint :subject_id
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :crm_audit_logs, [:account_id, :created_at]
    add_index :crm_audit_logs, [:subject_type, :subject_id]
  end
end
