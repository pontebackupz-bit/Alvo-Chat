class AddWebhookAuthToN8nConnections < ActiveRecord::Migration[7.0]
  def change
    add_column :crm_n8n_connections, :webhook_auth_header, :string
    add_column :crm_n8n_connections, :webhook_auth_value, :text
  end
end
