# Messages written now and sent by the platform at a chosen time.
class CreateCrmScheduledMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_scheduled_messages do |t|
      t.bigint :account_id, null: false
      t.bigint :conversation_id, null: false
      t.bigint :user_id, null: false
      t.text :content, null: false
      t.datetime :scheduled_at, null: false
      t.string :status, null: false, default: 'pending'
      t.bigint :message_id
      t.string :error_message
      t.datetime :sent_at
      t.timestamps
    end
    add_index :crm_scheduled_messages, [:status, :scheduled_at]
    add_index :crm_scheduled_messages, [:account_id, :conversation_id]
  end
end
