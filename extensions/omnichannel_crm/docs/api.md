# API REST

Todos os endpoints usam a autenticação atual do Chatwoot e o prefixo `/api/v1/accounts/:account_id/crm`.

| Recurso | Rotas |
| --- | --- |
| Leads | `GET/POST /leads`, `GET/PATCH /leads/:id`, `POST /leads/:id/convert` |
| Papéis | `GET/POST /roles`, `PATCH /roles/:id` |
| Atribuição de papéis | `GET/POST /role_assignments`, `DELETE /role_assignments/:id` |
| Supervisores | `GET/POST /team_supervisors`, `DELETE /team_supervisors/:id` |
| Regras n8n | CRUD `/automation_rules` |
| Regras de distribuição | CRUD `/distribution_rules` |
| Conexões n8n | `GET/POST /n8n_connections`, `PATCH/DELETE /n8n_connections/:id` |
| n8n | `GET /n8n_connections/:id/workflows`, `GET /n8n_connections/:id/executions`, `POST /n8n_connections/:id/workflows/:workflow_id/execute` |
| Dashboard | `GET /dashboard?start_at=&end_at=` |
| Auditoria | `GET /audit_logs?limit=100` |

Exemplo de automação:

```json
{
  "automation_rule": {
    "name": "Novo lead no ERP",
    "event_name": "lead.created",
    "n8n_connection_id": 1,
    "workflow_id": "wfl_123",
    "webhook_path": "crm/new-lead",
    "active": true,
    "filters": { "source": "whatsapp" }
  }
}
```

O corpo de execução manual aceita `webhook_path` e `payload`. O `workflow_id` identifica o workflow para a interface e auditoria; o webhook publicado é o contrato de execução, pois permite disparo estável sem chamar endpoints internos do n8n.
