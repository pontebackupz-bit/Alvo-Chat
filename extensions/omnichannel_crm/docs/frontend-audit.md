# Front-end audit

## Findings and corrections

The initial CRM UI used a custom visual language, hard-coded Portuguese strings, hand-built modal overlays and tables, and API payloads that did not match the engine's Rails strong parameters. Its dashboard also displayed static sample data and requested an invalid plural dashboard route.

The CRM now uses Chatwoot's `BaseSettingsHeader`, `Button`, `BaseTable`, `woot-modal`, `woot-loading-state`, design tokens and translated strings. It deliberately remains a small extension of the account dashboard rather than replacing Chatwoot settings, contacts, teams, conversations or reports.

## Completed modules

| Module | Screens and validation |
| --- | --- |
| Leads | List, create and edit. Uses `lead` payloads and real API responses. |
| n8n connections | List, create, edit and delete. The selected connection also lists workflows, shows local execution history and queues a manual webhook execution with an optional JSON payload. API keys are never rendered or returned by the engine. |
| Automation rules | List, create, edit and delete rules connected to n8n event/webhook workflows. |
| Distribution | List, create, edit and delete rules using supported strategies. |
| Access control | Role/permission overview and team supervisor assignment/removal. |
| Sales dashboard | Metrics, rankings and channel volume sourced from the dashboard API; no mock data. |

## Integration points

- Routes are registered below the existing account dashboard and links are added to the native sidebar.
- Front-end copy is defined only in `app/javascript/dashboard/i18n/locale/en/crm.json` and imported by the English locale bundle.
- Server-side CRM authorization remains the source of truth for every endpoint. The UI handles request failures through Chatwoot alerts.
- The responsive layouts use the existing spacing, color and typography tokens, including dark-mode-compatible token classes.

## Verification

- `pnpm exec eslint app/javascript/dashboard/api/crm.js app/javascript/dashboard/routes/dashboard/crm` passes in the Vite container.
- `pnpm exec vite build` passes in the Vite container.
- `bundle exec rails routes -g crm` confirms the engine routes, including dashboard, automation and n8n routes.

The repository-wide lint currently reports pre-existing Windows CRLF formatting errors outside the CRM files. No broad line-ending rewrite was performed.
