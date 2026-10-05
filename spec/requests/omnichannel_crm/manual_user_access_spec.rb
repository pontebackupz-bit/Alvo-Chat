require 'rails_helper'

RSpec.describe 'Manual CRM user access', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before do
    OmnichannelCrm::RoleDefaults.install_permissions!
    OmnichannelCrm::RoleDefaults.install(account)
  end

  describe 'POST /api/v1/accounts/:account_id/crm/users' do
    it 'creates a supervisor with a local textual CODUSUR and a temporary password' do
      post "/api/v1/accounts/#{account.id}/crm/users",
           params: {
             user: {
               name: 'Maria Silva',
               email: 'maria@example.com',
               codusur: '00042',
               access_profile: 'supervisor'
             }
           },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:created)
      created_user = User.find_by!(email: 'maria@example.com')
      account_user = account.account_users.find_by!(user: created_user)
      body = response.parsed_body

      expect(created_user.codusur).to eq('00042')
      expect(created_user.force_password_change).to be(true)
      expect(created_user.valid_password?(body.dig('credentials', 'temporary_password'))).to be(true)
      expect(account_user.role).to eq('agent')
      expect(OmnichannelCrm::RoleAssignment.find_by!(account: account, user: created_user).role.key).to eq('supervisor')
    end

    it 'maps administrator and agent profiles on the server' do
      {
        'administrator' => ['administrator', 'administrator'],
        'agent' => ['agent', 'seller']
      }.each do |profile, (account_role, crm_role)|
        post "/api/v1/accounts/#{account.id}/crm/users",
             params: {
               user: { name: profile, email: "#{profile}@example.com", access_profile: profile }
             },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:created)
        created_user = User.find_by!(email: "#{profile}@example.com")
        expect(account.account_users.find_by!(user: created_user).role).to eq(account_role)
        expect(OmnichannelCrm::RoleAssignment.find_by!(account: account, user: created_user).role.key).to eq(crm_role)
      end
    end

    it 'rejects an email that is already registered' do
      create(:user, email: 'maria@example.com')

      post "/api/v1/accounts/#{account.id}/crm/users",
           params: { user: { name: 'Maria Silva', email: 'maria@example.com', access_profile: 'agent' } },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('Já existe uma conta com este e-mail.')
    end

    it 'does not allow an agent to create accounts' do
      post "/api/v1/accounts/#{account.id}/crm/users",
           params: { user: { name: 'Maria Silva', email: 'maria@example.com', access_profile: 'agent' } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'regenerates a password, revokes old sessions, and requires a new change' do
      user = create(:user, account: account, password: 'SenhaAntiga123')
      old_session = user.create_new_auth_token

      post "/api/v1/accounts/#{account.id}/crm/users/#{account.account_users.find_by!(user: user).id}/reset_password",
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      new_password = response.parsed_body.dig('credentials', 'temporary_password')
      user.reload
      expect(user.force_password_change).to be(true)
      expect(user.valid_password?('SenhaAntiga123')).to be(false)
      expect(user.valid_password?(new_password)).to be(true)

      get '/api/v1/profile', headers: old_session, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not allow an agent to reset another user password' do
      user = create(:user, account: account)

      post "/api/v1/accounts/#{account.id}/crm/users/#{account.account_users.find_by!(user: user).id}/reset_password",
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'forced password change' do
    let(:temporary_password) { 'Brisa-cedro-42-AbCdEfGhJkL2' }
    let(:user) do
      create(:user, account: account, password: temporary_password, force_password_change: true)
    end

    it 'blocks protected APIs until the password is replaced' do
      headers = user.create_new_auth_token

      get '/api/v1/profile', headers: headers, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['code']).to eq('password_change_required')

      post '/api/v1/password_change',
           params: { password_change: { password: 'NovaSenha123', password_confirmation: 'NovaSenha123' } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(user.reload.force_password_change).to be(false)
      expect(user.valid_password?(temporary_password)).to be(false)
      expect(user.valid_password?('NovaSenha123')).to be(true)

      get '/api/v1/profile', headers: headers, as: :json
      expect(response).to have_http_status(:success)
    end

    it 'does not accept the temporary password as the new password' do
      post '/api/v1/password_change',
           params: { password_change: { password: temporary_password, password_confirmation: temporary_password } },
           headers: user.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.force_password_change).to be(true)
    end
  end
end
