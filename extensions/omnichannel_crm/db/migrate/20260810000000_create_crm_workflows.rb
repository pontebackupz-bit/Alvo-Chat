class CreateCrmWorkflows < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_workflows do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.text :description
      t.string :source, null: false, default: 'native'
      t.string :source_workflow_id
      t.jsonb :nodes, null: false, default: []
      t.jsonb :connections, null: false, default: []
      t.jsonb :variables, null: false, default: []
      t.jsonb :metadata, null: false, default: {}
      t.jsonb :import_report, null: false, default: {}
      t.timestamps
    end

    add_index :crm_workflows, [:account_id, :name]
    add_index :crm_workflows, [:account_id, :source, :source_workflow_id], unique: true,
              where: 'source_workflow_id IS NOT NULL', name: 'index_crm_workflows_by_import_source'
  end
end
