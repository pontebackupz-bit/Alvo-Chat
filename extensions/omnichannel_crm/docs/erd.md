# Modelo ERD

```mermaid
erDiagram
  ACCOUNT ||--o{ CRM_ROLE : owns
  CRM_ROLE ||--o{ CRM_ROLE_PERMISSION : grants
  CRM_PERMISSION ||--o{ CRM_ROLE_PERMISSION : includes
  ACCOUNT ||--o{ CRM_ROLE_ASSIGNMENT : scopes
  USER ||--o{ CRM_ROLE_ASSIGNMENT : receives
  CRM_ROLE ||--o{ CRM_ROLE_ASSIGNMENT : assigned
  ACCOUNT ||--o{ CRM_TEAM_SUPERVISOR : scopes
  TEAM ||--o{ CRM_TEAM_SUPERVISOR : supervised
  USER ||--o{ CRM_TEAM_SUPERVISOR : supervises
  ACCOUNT ||--o{ CRM_LEAD : owns
  CONTACT ||--|| CRM_LEAD : represents
  CONVERSATION o|--o| CRM_LEAD : originates
  USER o|--o{ CRM_LEAD : owns
  ACCOUNT ||--o{ CRM_N8N_CONNECTION : configures
  CRM_N8N_CONNECTION ||--o{ CRM_AUTOMATION_RULE : runs
  CRM_AUTOMATION_RULE ||--o{ CRM_WORKFLOW_EXECUTION : generates
  CRM_N8N_CONNECTION ||--o{ CRM_WORKFLOW_EXECUTION : handles
  ACCOUNT ||--o{ CRM_DISTRIBUTION_RULE : configures
  TEAM o|--o{ CRM_DISTRIBUTION_RULE : targets
  ACCOUNT ||--o{ CRM_AUDIT_LOG : records
  USER o|--o{ CRM_AUDIT_LOG : acts
```

As relações com `Account`, `User`, `Team`, `Contact` e `Conversation` são lógicas. O engine não cria chaves estrangeiras para tabelas do Chatwoot, reduzindo o acoplamento com migrações futuras do núcleo.
