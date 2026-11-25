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

  getBaileysSession(accountId, params = {}) {
    return axios.get(`${this.accountUrl(accountId)}/baileys_session`, {
      params,
    });
  }

  createBaileysSession(accountId, data = {}) {
    return axios.post(`${this.accountUrl(accountId)}/baileys_session`, data);
  }

  deleteBaileysSession(accountId, params = {}) {
    return axios.delete(`${this.accountUrl(accountId)}/baileys_session`, {
      params,
    });
  }

  getWppconnectSession(accountId, params = {}) {
    return axios.get(`${this.accountUrl(accountId)}/wppconnect_session`, {
      params,
    });
  }

  createWppconnectSession(accountId, data = {}) {
    return axios.post(`${this.accountUrl(accountId)}/wppconnect_session`, data);
  }

  deleteWppconnectSession(accountId, params = {}) {
    return axios.delete(`${this.accountUrl(accountId)}/wppconnect_session`, {
      params,
    });
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

  getN8nWorkflow(accountId, connectionId, workflowId) {
    return axios.get(
      `${this.accountUrl(accountId)}/n8n_connections/${connectionId}/workflows/${workflowId}`
    );
  }

  createN8nWorkflow(accountId, connectionId, workflow) {
    return axios.post(
      `${this.accountUrl(accountId)}/n8n_connections/${connectionId}/workflows`,
      { workflow }
    );
  }

  updateN8nWorkflow(accountId, connectionId, workflowId, workflow) {
    return axios.put(
      `${this.accountUrl(accountId)}/n8n_connections/${connectionId}/workflows/${workflowId}`,
      { workflow }
    );
  }

  setN8nWorkflowActive(accountId, connectionId, workflowId, active) {
    return axios.post(
      `${this.accountUrl(accountId)}/n8n_connections/${connectionId}/workflows/${workflowId}/activate`,
      { active }
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

  getUsers(accountId) {
    return axios.get(`${this.accountUrl(accountId)}/users`);
  }

  createUser(accountId, data) {
    return axios.post(`${this.accountUrl(accountId)}/users`, { user: data });
  }

  updateUser(accountId, userId, data) {
    return axios.patch(`${this.accountUrl(accountId)}/users/${userId}`, {
      user: data,
    });
  }

  resetUserPassword(accountId, userId, data = {}) {
    return axios.post(
      `${this.accountUrl(accountId)}/users/${userId}/reset_password`,
      {
        user: data,
      }
    );
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

  getWorkflows(accountId) {
    return axios.get(`${this.accountUrl(accountId)}/workflows`);
  }

  getWorkflow(accountId, workflowId) {
    return axios.get(`${this.accountUrl(accountId)}/workflows/${workflowId}`);
  }

  createWorkflow(accountId, data) {
    return axios.post(`${this.accountUrl(accountId)}/workflows`, {
      workflow: data,
    });
  }

  deleteWorkflow(accountId, workflowId) {
    return axios.delete(
      `${this.accountUrl(accountId)}/workflows/${workflowId}`
    );
  }

  previewWorkflowImport(accountId, file) {
    const data = new FormData();
    data.append('file', file);
    return axios.post(`${this.accountUrl(accountId)}/workflows/preview`, data);
  }

  importWorkflow(accountId, file) {
    const data = new FormData();
    data.append('file', file);
    return axios.post(`${this.accountUrl(accountId)}/workflows/import`, data);
  }

  updateWorkflow(accountId, workflowId, data) {
    return axios.patch(
      `${this.accountUrl(accountId)}/workflows/${workflowId}`,
      {
        workflow: data,
      }
    );
  }

  exportWorkflow(accountId, workflowId) {
    return axios.get(
      `${this.accountUrl(accountId)}/workflows/${workflowId}/export`,
      { responseType: 'blob' }
    );
  }

  getWorkflowReadiness(accountId, workflowId) {
    return axios.get(
      `${this.accountUrl(accountId)}/workflows/${workflowId}/readiness`
    );
  }

  getWorkflowMetrics(accountId, workflowId, params = {}) {
    return axios.get(
      `${this.accountUrl(accountId)}/workflows/${workflowId}/metrics`,
      { params }
    );
  }

  getConnections(accountId) {
    return axios.get(`${this.accountUrl(accountId)}/connections`);
  }

  createConnection(accountId, data) {
    return axios.post(`${this.accountUrl(accountId)}/connections`, data);
  }

  updateConnection(accountId, inboxId, data) {
    return axios.patch(
      `${this.accountUrl(accountId)}/connections/${inboxId}`,
      data
    );
  }

  deleteConnection(accountId, inboxId) {
    return axios.delete(`${this.accountUrl(accountId)}/connections/${inboxId}`);
  }

  getAttendanceStats(accountId) {
    return axios.get(`${this.accountUrl(accountId)}/attendance/stats`);
  }

  getChatHistory(accountId, params = {}) {
    return axios.get(`${this.accountUrl(accountId)}/attendance/history`, {
      params,
    });
  }

  getScheduledMessages(accountId, params = {}) {
    return axios.get(`${this.accountUrl(accountId)}/scheduled_messages`, {
      params,
    });
  }

  createScheduledMessage(accountId, data) {
    return axios.post(`${this.accountUrl(accountId)}/scheduled_messages`, data);
  }

  cancelScheduledMessage(accountId, id) {
    return axios.delete(
      `${this.accountUrl(accountId)}/scheduled_messages/${id}`
    );
  }

  getConversationHistory(accountId, conversationId) {
    return axios.get(
      `${this.accountUrl(accountId)}/conversations/${conversationId}/whatsapp_history`
    );
  }

  importConversationHistory(accountId, conversationId) {
    return axios.post(
      `${this.accountUrl(accountId)}/conversations/${conversationId}/whatsapp_history`
    );
  }

  sendRichMessage(accountId, conversationId, payload) {
    return axios.post(
      `${this.accountUrl(accountId)}/conversations/${conversationId}/rich_messages`,
      payload
    );
  }

  transcribeAudio(accountId, attachmentId) {
    return axios.post(
      `${this.accountUrl(accountId)}/attachments/${attachmentId}/transcription`
    );
  }

  getContactPicture(accountId, params) {
    return axios.get(`${this.accountUrl(accountId)}/contact_picture`, {
      params,
    });
  }

  startConversation(accountId, payload) {
    return axios.post(
      `${this.accountUrl(accountId)}/conversations/start`,
      payload
    );
  }

  askCopilot(accountId, conversationId, payload) {
    return axios.post(
      `${this.accountUrl(accountId)}/conversations/${conversationId}/copilot`,
      payload
    );
  }

  importConnectionHistory(accountId, inboxId) {
    return axios.post(
      `${this.accountUrl(accountId)}/connections/${inboxId}/import_history`
    );
  }

  getConnection(accountId, inboxId) {
    return axios.get(`${this.accountUrl(accountId)}/connections/${inboxId}`);
  }

  reconnectConnection(accountId, inboxId) {
    return axios.post(
      `${this.accountUrl(accountId)}/connections/${inboxId}/reconnect`
    );
  }

  getDashboardMetrics(accountId, params = {}) {
    return axios.get(`${this.accountUrl(accountId)}/dashboard`, { params });
  }

  getAuditLogs(accountId) {
    return axios.get(`${this.accountUrl(accountId)}/audit_logs`);
  }
}

export default new CrmAPI();
