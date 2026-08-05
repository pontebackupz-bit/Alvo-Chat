# Plano de implementação

## Fase 0 — Fundação

- Criar ambiente Chatwoot com PostgreSQL, Redis, Sidekiq e storage compatível.
- Configurar chaves de criptografia Active Record, backups e observabilidade.
- Instalar o engine, migrar banco e semear papéis por conta.

## Fase 1 — Operação comercial

- Habilitar os canais nativos Chatwoot e definir convenções de tags, equipes e responsáveis.
- Ativar o lifecycle de leads e importar classificação comercial existente.
- Configurar perfis, supervisores por equipe e regras de distribuição.

## Fase 2 — Automação

- Registrar instância n8n com chave de escopo mínimo.
- Criar Webhook Trigger por workflow publicado e cadastrar o caminho no CRM.
- Ativar uma regra por vez e validar payload, idempotência no destino e histórico de execução.

## Fase 3 — Gestão

- Validar dashboard contra uma amostra de conversas do Chatwoot.
- Definir metas, SLA e critérios de conversão aprovados pela operação.
- Construir a tela Vue do CRM consumindo a API do engine; manter a caixa de entrada nativa nas primeiras entregas.

## Critérios de aceite

- Um contato de cada canal gera ou associa um lead sem duplicação por conta.
- Vendedor não visualiza lead/conversa que não lhe pertence; supervisor só observa suas equipes.
- Uma automação registra `queued`, `running`, `succeeded` ou `failed` e não expõe API Key.
- Distribuição não atribui conversa a usuário offline e mantém uma trilha de auditoria.
