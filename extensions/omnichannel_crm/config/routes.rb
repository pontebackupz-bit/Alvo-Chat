OmnichannelCrm::Engine.routes.draw do
  resource :password_change, only: [:create]
  post 'baileys/:session_id/messages', to: 'baileys_messages#create'
  put 'baileys/:session_id/contacts/:source_id', to: 'baileys_messages#update_contact'
  post 'wppconnect/:token/messages', to: 'wppconnect_messages#create'
  scope 'accounts/:account_id/crm' do
    resources :leads, only: [:index, :show, :create, :update] do
      post :convert, on: :member
    end

    resources :roles, only: [:index, :create, :update]
    resources :users, only: [:index, :create, :update] do
      post :reset_password, on: :member
    end
    resources :role_assignments, only: [:index, :create, :destroy]
    resources :team_supervisors, only: [:index, :create, :destroy]
    resources :automation_rules
    resources :workflows, only: [:index, :show, :create, :update, :destroy] do
      get :export, on: :member
      get :metrics, on: :member
      get :readiness, on: :member
      collection do
        post :preview
        post :import
      end
    end
    resources :distribution_rules
    resources :n8n_connections, only: [:index, :create, :update, :destroy] do
      get :workflows, on: :member
      get :executions, on: :member
      post :workflows, to: 'n8n_connections#create_workflow', on: :member, as: :create_workflow
      get 'workflows/:workflow_id', to: 'n8n_connections#workflow', on: :member
      put 'workflows/:workflow_id', to: 'n8n_connections#update_workflow', on: :member
      post 'workflows/:workflow_id/activate', to: 'n8n_connections#activate_workflow', on: :member
      post 'workflows/:workflow_id/execute', to: 'n8n_connections#execute_workflow', on: :member
    end
    resource :baileys_session, only: [:show, :create, :destroy] do
      post :refresh
    end
    resource :wppconnect_session, only: [:show, :create, :destroy] do
      post :refresh
    end
    resource :dashboard, only: [:show]
    get 'attendance/stats', to: 'attendance#stats'
    get 'attendance/history', to: 'attendance#history'
    resources :scheduled_messages, only: [:index, :create, :destroy]
    resource :whatsapp_history, only: [:show, :create], path: 'conversations/:conversation_id/whatsapp_history',
                                controller: 'conversation_histories'
    post 'conversations/start', to: 'conversation_starts#create'
    get 'contact_picture', to: 'conversation_starts#picture'
    post 'attachments/:attachment_id/transcription', to: 'audio_transcriptions#create'
    post 'conversations/:conversation_id/rich_messages', to: 'rich_messages#create'
    resource :copilot, only: [:create], path: 'conversations/:conversation_id/copilot', controller: 'conversation_copilots'
    resources :connections, only: [:index, :show, :create, :update, :destroy] do
      post :reconnect, on: :member
      post :import_history, on: :member
    end
    resources :audit_logs, only: [:index]
  end
end
