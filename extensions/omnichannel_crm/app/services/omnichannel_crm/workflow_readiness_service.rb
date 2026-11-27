# What a flow still needs from the account to run as designed: subflows to
# import, teams and people to create, integrations that are not available.
#
# Each item is `{ node_id:, level:, kind:, message: }`. `blocking` items stop
# the flow from being activated; `warning` items run, but through a fallback
# path (the block's error output, or the end of the flow).
class OmnichannelCrm::WorkflowReadinessService
  INTEGRATIONS = { 'oracle' => 'Oracle (Winthor)', 'google_sheets' => 'Google Sheets' }.freeze

  def initialize(workflow)
    @workflow = workflow
    @account = workflow.account
  end

  def perform
    @workflow.nodes.flat_map { |node| issues_for(node) }
  end

  private

  def issues_for(node)
    data = node['data'] || {}
    issue = case node['type']
            when 'subflow' then subflow_issue(data)
            when 'transfer_team' then team_issue(data)
            when 'assign_agent' then agent_issue(data)
            when 'integration' then integration_issue(data)
            when 'code' then code_issue(data)
            when 'unsupported_imported_node'
              [:blocking, 'unsupported', "Bloco “#{data['originalType']}” não é suportado. Substitua ou remova."]
            end
    issue ? [{ node_id: node['id'], level: issue[0], kind: issue[1], message: issue[2] }] : []
  end

  def subflow_issue(data)
    name = data['flow_name'].to_s
    return [:blocking, 'subflow', 'Escolha o fluxo que este bloco executa.'] if name.blank?
    return if workflow_names.include?(comparable(name))

    [:warning, 'subflow', "Importe o fluxo “#{name}”. Enquanto ele não existir, o fluxo segue pela saída de erro (ou termina aqui)."]
  end

  def team_issue(data)
    return if data['team_id'].present? && @account.teams.exists?(id: data['team_id'])
    return [:blocking, 'team', 'Escolha a equipe que recebe a conversa.'] if data['team_name'].blank?
    return if team_names.include?(comparable(data['team_name']))

    [:warning, 'team', "Crie a equipe “#{data['team_name']}” (ou escolha outra no bloco). Sem ela, o fluxo segue pela saída de erro."]
  end

  def agent_issue(data)
    return if data['agent_id'].present? || data['agent_email'].to_s.include?('{{')
    return [:blocking, 'agent', 'Escolha a pessoa que recebe a conversa.'] if data['agent_email'].blank?
    return if agent_emails.include?(data['agent_email'].to_s.downcase)

    [:warning, 'agent', "Nenhum usuário com o e-mail #{data['agent_email']}. O fluxo trata essa pessoa como offline."]
  end

  def integration_issue(data)
    name = INTEGRATIONS.fetch(data['provider'].to_s, data['provider'].to_s)
    [:warning, 'integration', "A integração #{name} não está conectada ao AlvoChat. O fluxo segue pela saída de erro."]
  end

  def code_issue(data)
    return if data['code'].to_s.match?(OmnichannelCrm::FlowNodes::Logic::DIGITS_ONLY_CODE)

    [:warning, 'code', 'Este código JavaScript não roda no AlvoChat. O fluxo segue pela saída de erro.']
  end

  def workflow_names
    @workflow_names ||= OmnichannelCrm::Workflow.where(account_id: @workflow.account_id).where.not(id: @workflow.id)
                                                .pluck(:name).map { |name| comparable(name) }
  end

  def team_names
    @team_names ||= @account.teams.pluck(:name).map { |name| comparable(name) }
  end

  def agent_emails
    @agent_emails ||= @account.users.pluck(:email).map(&:downcase)
  end

  def comparable(name)
    ActiveSupport::Inflector.transliterate(name.to_s).downcase.gsub(/[^a-z0-9]+/, ' ').strip
  end
end
