/* global axios */

import ApiClient from './ApiClient';

class CrmAPI extends ApiClient {
  constructor() {
    super('crm', { accountScoped: true });
  }

  accountUrl(accountId) {
    return `${this.apiVersion}/accounts/${accountId}/crm`;
  }

  getLeads(accountId, params = {}) {
    return axios.get(`${this.accountUrl(accountId)}/leads`, { params });
  }

  createLead(accountId, data) {
    return axios.post(`${this.accountUrl(accountId)}/leads`, { lead: data });
  }

  updateLead(accountId, leadId, data) {
    return axios.patch(`${this.accountUrl(accountId)}/leads/${leadId}`, {
      lead: data,
    });
  }

  getN8nConnections(accountId) {
    return axios.get(`${this.accountUrl(accountId)}/n8n_connections`);
  }

  createN8nConnection(accountId, data) {
    return axios.post(`${this.accountUrl(accountId)}/n8n_connections`, {
      n8n_connection: data,
    });
  }

  updateN8nConnection(accountId, connectionId, data) {
    return axios.patch(
      `${this.accountUrl(accountId)}/n8n_connections/${connectionId}`,
      {
        n8n_connection: data,
      }
    );
  }

  deleteN8nConnection(accountId, connectionId) {
    return axios.delete(
      `${this.accountUrl(accountId)}/n8n_connections/${connectionId}`
    );
  }

  getBaileysSession(accountId) {
    return axios.get(`${this.accountUrl(accountId)}/baileys_session`);
  }

  createBaileysSession(accountId) {
    return axios.post(`${this.accountUrl(accountId)}/baileys_session`);
  }

  getN8nWorkflows(accountId, connectionId) {
    return axios.get(
      `${this.accountUrl(accountId)}/n8n_connections/${connectionId}/workflows`
    );
  }

  getN8nExecutions(accountId, connectionId) {
    return axios.get(
      `${this.accountUrl(accountId)}/n8n_connections/${connectionId}/executions`
    );
  }

  executeN8nWorkflow(accountId, connectionId, workflowId, data) {
    return axios.post(
      `${this.accountUrl(accountId)}/n8n_connections/${connectionId}/workflows/${workflowId}/execute`,
      data
    );
  }

  getDistributionRules(accountId) {
    return axios.get(`${this.accountUrl(accountId)}/distribution_rules`);
  }

  createDistributionRule(accountId, data) {
    return axios.post(`${this.accountUrl(accountId)}/distribution_rules`, {
      distribution_rule: data,
    });
  }

  updateDistributionRule(accountId, ruleId, data) {
    return axios.patch(
      `${this.accountUrl(accountId)}/distribution_rules/${ruleId}`,
      {
        distribution_rule: data,
      }
    );
  }

  deleteDistributionRule(accountId, ruleId) {
    return axios.delete(
      `${this.accountUrl(accountId)}/distribution_rules/${ruleId}`
    );
  }

  getRoles(accountId) {
    return axios.get(`${this.accountUrl(accountId)}/roles`);
  }

  getRoleAssignments(accountId) {
    return axios.get(`${this.accountUrl(accountId)}/role_assignments`);
  }

  createRoleAssignment(accountId, data) {
    return axios.post(`${this.accountUrl(accountId)}/role_assignments`, {
      role_assignment: data,
    });
  }

  deleteRoleAssignment(accountId, assignmentId) {
    return axios.delete(
      `${this.accountUrl(accountId)}/role_assignments/${assignmentId}`
    );
  }

  getTeamSupervisors(accountId) {
    return axios.get(`${this.accountUrl(accountId)}/team_supervisors`);
  }

  assignTeamSupervisor(accountId, data) {
    return axios.post(`${this.accountUrl(accountId)}/team_supervisors`, {
      team_supervisor: data,
    });
  }

  deleteTeamSupervisor(accountId, supervisorId) {
    return axios.delete(
      `${this.accountUrl(accountId)}/team_supervisors/${supervisorId}`
    );
  }

  getAutomationRules(accountId) {
    return axios.get(`${this.accountUrl(accountId)}/automation_rules`);
  }

  createAutomationRule(accountId, data) {
    return axios.post(`${this.accountUrl(accountId)}/automation_rules`, {
      automation_rule: data,
    });
  }

  updateAutomationRule(accountId, ruleId, data) {
    return axios.patch(
      `${this.accountUrl(accountId)}/automation_rules/${ruleId}`,
      {
        automation_rule: data,
      }
    );
  }

  deleteAutomationRule(accountId, ruleId) {
    return axios.delete(
      `${this.accountUrl(accountId)}/automation_rules/${ruleId}`
    );
  }

  getDashboardMetrics(accountId) {
    return axios.get(`${this.accountUrl(accountId)}/dashboard`);
  }

  getAuditLogs(accountId) {
    return axios.get(`${this.accountUrl(accountId)}/audit_logs`);
  }
}

export default new CrmAPI();
