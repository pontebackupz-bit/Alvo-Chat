OmnichannelCrm::Engine.routes.draw do
  post 'baileys/:session_id/messages', to: 'baileys_messages#create'
  put 'baileys/:session_id/contacts/:source_id', to: 'baileys_messages#update_contact'
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
    resources :workflows, only: [:index, :show, :update] do
      get :export, on: :member
      collection do
        post :preview
        post :import
      end
    end
    resources :distribution_rules
    resources :n8n_connections, only: [:index, :create, :update, :destroy] do
      get :workflows, on: :member
      get :executions, on: :member
      post 'workflows/:workflow_id/execute', to: 'n8n_connections#execute_workflow', on: :member
    end
    resource :baileys_session, only: [:show, :create, :destroy]
    resource :dashboard, only: [:show]
    resources :audit_logs, only: [:index]
  end
end
