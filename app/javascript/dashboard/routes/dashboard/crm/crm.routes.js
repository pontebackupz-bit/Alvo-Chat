import CrmIndex from './CrmIndex.vue';
import LeadsView from './LeadsView.vue';
import N8nView from './N8nView.vue';
import AutomationView from './AutomationView.vue';
import DistributionView from './DistributionView.vue';
import RolesView from './RolesView.vue';
import DashboardView from './DashboardView.vue';
import AuditLogsView from './AuditLogsView.vue';
import WorkflowsView from './WorkflowsView.vue';
import { frontendURL } from '../../../helper/URLHelper';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/crm'),
    component: CrmIndex,
    redirect: to => frontendURL(`accounts/${to.params.accountId}/crm/leads`),
    name: 'crm_parent',
    meta: { permissions: ['administrator', 'agent', 'custom_role'] },
    children: [
      {
        path: 'leads',
        name: 'crm_leads',
        component: LeadsView,
        meta: { permissions: ['administrator', 'agent', 'custom_role'] },
      },
      {
        path: 'n8n',
        name: 'crm_n8n',
        component: N8nView,
        meta: { permissions: ['administrator', 'agent', 'custom_role'] },
      },
      {
        path: 'automation',
        name: 'crm_automation',
        component: AutomationView,
        meta: { permissions: ['administrator', 'agent', 'custom_role'] },
      },
      {
        path: 'workflows',
        name: 'crm_workflows',
        component: WorkflowsView,
        meta: { permissions: ['administrator', 'agent', 'custom_role'] },
      },
      {
        path: 'distribution',
        name: 'crm_distribution',
        component: DistributionView,
        meta: { permissions: ['administrator', 'agent', 'custom_role'] },
      },
      {
        path: 'roles',
        name: 'crm_roles',
        component: RolesView,
        meta: { permissions: ['administrator', 'agent', 'custom_role'] },
      },
      {
        path: 'dashboard',
        name: 'crm_dashboard',
        component: DashboardView,
        meta: { permissions: ['administrator', 'agent', 'custom_role'] },
      },
      {
        path: 'audit-logs',
        name: 'crm_audit_logs',
        component: AuditLogsView,
        meta: { permissions: ['administrator', 'agent', 'custom_role'] },
      },
    ],
  },
];
