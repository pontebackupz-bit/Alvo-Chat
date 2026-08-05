# Plano de migração

## Pré-migração

1. Fazer backup consistente de PostgreSQL e arquivos de storage.
2. Registrar versão/commit do Chatwoot e executar a suíte de smoke test da instância atual.
3. Inventariar contas, equipes, usuários, inboxes, tags e automações existentes.

## Implantação

1. Criar uma branch baseada na versão Chatwoot homologada e adicionar o engine.
2. Executar `bundle install` e `bundle exec rails db:migrate` em manutenção programada.
3. Para cada conta, executar `ACCOUNT_ID=<id> bundle exec rails omnichannel_crm:seed_roles`.
4. Criar as atribuições CRM e supervisores sem alterar o papel nativo `AccountUser`.
5. Cadastrar conexões n8n, testar um Webhook Trigger de homologação e só então ativar regras.

## Rollback

Desative regras de automação e distribuição antes de reverter a aplicação. As tabelas `crm_*` são aditivas e não modificam dados Chatwoot; preserve-as para investigação. Se for necessário rollback de schema, gere uma migration reversa revisada em vez de remover dados produtivos de forma automática.

## Atualização do Chatwoot

Atualize o upstream primeiro em branch separada. Em homologação: execute migrations oficiais, verifique o carregamento do engine, valide os nove eventos normalizados, uma execução n8n e os três perfis RBAC. Só depois promova a mesma sequência à produção.
