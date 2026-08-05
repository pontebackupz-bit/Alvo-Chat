# CRM Omnichannel extension

Extensão Rails Engine para transformar uma instalação Chatwoot em CRM omnichannel sem duplicar contatos, conversas, mensagens, equipes ou canais. O Chatwoot permanece a fonte de verdade desses recursos; o engine armazena somente os dados comerciais, RBAC complementar, automações, execuções e auditoria.

## Instalação

1. Configure as chaves de Active Record Encryption do Chatwoot. Elas protegem a API Key do n8n.
2. Execute `bundle install` na raiz do Chatwoot.
3. Execute `bundle exec rails db:migrate`.
4. Para cada conta: `ACCOUNT_ID=1 bundle exec rails omnichannel_crm:seed_roles`.
5. Reinicie os processos Rails e Sidekiq.

O engine é montado em `/api/v1`; seus endpoints ficam sob `/accounts/:account_id/crm`. Consulte `docs/` para API, RBAC, arquitetura e plano de implantação.

## Contrato n8n

`base_url` é a raiz da instância, por exemplo `https://n8n.example.com`. A listagem usa a Public API (`/api/v1/workflows`) com `X-N8N-API-KEY`. Execuções são entregues a um Webhook Trigger publicado no caminho salvo em `webhook_path`, por exemplo `crm/new-lead`. Isso evita depender de APIs internas do editor n8n para iniciar um workflow.
