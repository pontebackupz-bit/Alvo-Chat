# RBAC e escopo hierárquico

O papel nativo `AccountUser.administrator` do Chatwoot continua sendo a autoridade máxima e recebe acesso completo ao CRM. Papéis CRM ficam em `crm_role_assignments` por conta, portanto um mesmo usuário pode ter perfis diferentes em contas diferentes.

| Papel | Escopo de conversas | Capacidades |
| --- | --- | --- |
| Administrator | todas | usuários, equipes, integrações, automação, dashboards e auditoria |
| Supervisor | equipes designadas em `crm_team_supervisors` | leads da equipe, distribuição, automação, métricas e auditoria |
| Seller | conversas atribuídas ao próprio usuário | visualizar e atualizar os próprios leads, responder pelo Chatwoot |

Permissões são strings como `leads.read`, `leads.manage`, `dashboards.read`, `distribution.manage`, `automation.manage`, `integrations.manage`, `users.manage`, `teams.manage`, `settings.manage` e `audit.read`. A permissão `*` é reservada ao administrador CRM.

O endpoint de conversas existente do Chatwoot permanece responsável pelo bloqueio de UI e acesso nativo. Qualquer novo endpoint CRM precisa passar por `OmnichannelCrm::Authorization`; não confie no front-end para aplicar escopo.
