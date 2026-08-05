<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { BaseTable } from 'dashboard/components-next/table';
import Button from 'dashboard/components-next/button/Button.vue';
import crmAPI from 'dashboard/api/crm';
import CrmPageHeader from './CrmPageHeader.vue';

const { t } = useI18n();
const route = useRoute();
const accountId = computed(() => route.params.accountId);
const connections = ref([]);
const isLoading = ref(false);
const isSaving = ref(false);
const showModal = ref(false);
const showExecutionModal = ref(false);
const selectedConnection = ref(null);
const selectedWorkflow = ref(null);
const workflows = ref([]);
const executions = ref([]);
const isDetailsLoading = ref(false);
const form = ref({
  name: '',
  base_url: '',
  api_key: '',
  webhook_auth_header: '',
  webhook_auth_value: '',
  active: true,
});
const executionForm = ref({ workflow_id: '', webhook_path: '', payload: '{}' });
const headers = computed(() => [
  t('CRM.N8N.NAME'),
  t('CRM.N8N.URL'),
  t('CRM.COMMON.STATUS'),
  t('CRM.COMMON.ACTIONS'),
]);
const events = [
  'lead.created',
  'conversation.created',
  'message.received',
  'message.sent',
  'conversation.resolved',
  'contact.created',
  'lead.converted',
  'assignee.changed',
  'conversation.status_changed',
];

const normalizeN8nItems = data => {
  if (Array.isArray(data)) return data;
  return data?.data || data?.workflows || [];
};

const fetchConnections = async () => {
  isLoading.value = true;
  try {
    const { data } = await crmAPI.getN8nConnections(accountId.value);
    connections.value = Array.isArray(data) ? data : data.n8n_connections || [];
  } catch (error) {
    useAlert(t('CRM.N8N.FETCH_ERROR'));
  } finally {
    isLoading.value = false;
  }
};
const openCreate = () => {
  selectedConnection.value = null;
  form.value = {
    name: '',
    base_url: '',
    api_key: '',
    webhook_auth_header: '',
    webhook_auth_value: '',
    active: true,
  };
  showModal.value = true;
};
const openEdit = connection => {
  selectedConnection.value = connection;
  form.value = {
    name: connection.name,
    base_url: connection.base_url,
    api_key: '',
    webhook_auth_header: connection.webhook_auth_header || '',
    webhook_auth_value: '',
    active: connection.active,
  };
  showModal.value = true;
};
const closeModal = () => {
  showModal.value = false;
  selectedConnection.value = null;
};
const saveConnection = async () => {
  isSaving.value = true;
  const payload = { ...form.value };
  if (selectedConnection.value && !payload.api_key) delete payload.api_key;
  if (selectedConnection.value && !payload.webhook_auth_value) {
    delete payload.webhook_auth_value;
  }
  try {
    if (selectedConnection.value) {
      await crmAPI.updateN8nConnection(
        accountId.value,
        selectedConnection.value.id,
        payload
      );
      useAlert(t('CRM.N8N.UPDATE_SUCCESS'));
    } else {
      await crmAPI.createN8nConnection(accountId.value, payload);
      useAlert(t('CRM.N8N.CREATE_SUCCESS'));
    }
    closeModal();
    await fetchConnections();
  } catch (error) {
    useAlert(t('CRM.N8N.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};
const deleteConnection = async connection => {
  try {
    await crmAPI.deleteN8nConnection(accountId.value, connection.id);
    if (selectedConnection.value?.id === connection.id) {
      selectedConnection.value = null;
      workflows.value = [];
      executions.value = [];
    }
    await fetchConnections();
    useAlert(t('CRM.N8N.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(t('CRM.N8N.SAVE_ERROR'));
  }
};

const fetchConnectionDetails = async connection => {
  selectedConnection.value = connection;
  isDetailsLoading.value = true;
  try {
    const [workflowsResponse, executionsResponse] = await Promise.allSettled([
      crmAPI.getN8nWorkflows(accountId.value, connection.id),
      crmAPI.getN8nExecutions(accountId.value, connection.id),
    ]);
    if (workflowsResponse.status === 'fulfilled') {
      workflows.value = normalizeN8nItems(workflowsResponse.value.data);
    } else {
      workflows.value = [];
      useAlert(t('CRM.N8N.WORKFLOWS_ERROR'));
    }
    if (executionsResponse.status === 'fulfilled') {
      executions.value = normalizeN8nItems(executionsResponse.value.data);
    } else {
      executions.value = [];
      useAlert(t('CRM.N8N.EXECUTIONS_ERROR'));
    }
  } finally {
    isDetailsLoading.value = false;
  }
};

const openExecution = workflow => {
  selectedWorkflow.value = workflow || null;
  executionForm.value = {
    workflow_id: workflow?.id || '',
    webhook_path: '',
    payload: '{}',
  };
  showExecutionModal.value = true;
};

const closeExecutionModal = () => {
  showExecutionModal.value = false;
  selectedWorkflow.value = null;
};

const executeWorkflow = async () => {
  let payload;
  try {
    payload = JSON.parse(executionForm.value.payload || '{}');
  } catch (error) {
    useAlert(t('CRM.N8N.PAYLOAD_ERROR'));
    return;
  }

  isSaving.value = true;
  try {
    await crmAPI.executeN8nWorkflow(
      accountId.value,
      selectedConnection.value.id,
      executionForm.value.workflow_id,
      { webhook_path: executionForm.value.webhook_path, payload }
    );
    useAlert(t('CRM.N8N.RUN_SUCCESS'));
    closeExecutionModal();
    await fetchConnectionDetails(selectedConnection.value);
  } catch (error) {
    useAlert(t('CRM.N8N.RUN_ERROR'));
  } finally {
    isSaving.value = false;
  }
};
onMounted(fetchConnections);
</script>

<template>
  <section>
    <CrmPageHeader
      :title="$t('CRM.N8N.TITLE')"
      :description="$t('CRM.N8N.DESCRIPTION')"
      :action-label="$t('CRM.N8N.NEW')"
      action-icon="i-lucide-plus"
      @action="openCreate"
    />
    <woot-loading-state v-if="isLoading" :message="$t('CRM.COMMON.LOADING')" />
    <template v-else>
      <BaseTable
        :headers="headers"
        :items="connections"
        :no-data-message="$t('CRM.N8N.EMPTY')"
      >
        <template #row="{ items }"
          ><tr v-for="connection in items" :key="connection.id">
            <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-12">
              {{ connection.name }}
            </td>
            <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
              {{ connection.base_url }}
            </td>
            <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
              {{
                connection.active
                  ? $t('CRM.COMMON.ACTIVE')
                  : $t('CRM.COMMON.INACTIVE')
              }}
            </td>
            <td class="py-4 text-right">
              <div class="crm-table-actions">
                <Button
                  variant="link"
                  size="sm"
                  :label="$t('CRM.COMMON.EDIT')"
                  @click="openEdit(connection)"
                />
                <Button
                  variant="link"
                  size="sm"
                  :label="$t('CRM.N8N.OPEN')"
                  @click="fetchConnectionDetails(connection)"
                />
                <Button
                  variant="link"
                  color="ruby"
                  size="sm"
                  :label="$t('CRM.COMMON.DELETE')"
                  @click="deleteConnection(connection)"
                />
              </div>
            </td></tr
        ></template>
      </BaseTable>
      <div
        v-if="selectedConnection"
        class="mt-8 border-t border-n-weak pt-6"
      >
        <h2 class="text-heading-3 text-n-slate-12">
          {{ $t('CRM.N8N.DETAILS', { name: selectedConnection.name }) }}
        </h2>
        <woot-loading-state
          v-if="isDetailsLoading"
          :message="$t('CRM.COMMON.LOADING')"
        />
        <template v-else>
          <div class="flex items-center justify-between gap-3 mt-5">
            <h3 class="text-body-main font-medium text-n-slate-12">
              {{ $t('CRM.N8N.WORKFLOWS') }}
            </h3>
            <Button
              size="sm"
              variant="faded"
              color="slate"
              :label="$t('CRM.N8N.RUN_MANUAL')"
              @click="openExecution()"
            />
          </div>
          <BaseTable
            :headers="[
              $t('CRM.N8N.NAME'),
              $t('CRM.N8N.WORKFLOW'),
              $t('CRM.COMMON.STATUS'),
              $t('CRM.COMMON.ACTIONS'),
            ]"
            :items="workflows"
            :no-data-message="$t('CRM.N8N.WORKFLOWS_EMPTY')"
          >
            <template #row="{ items }">
              <tr v-for="workflow in items" :key="workflow.id">
                <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-12">
                  {{ workflow.name || workflow.id }}
                </td>
                <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
                  {{ workflow.id }}
                </td>
                <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
                  {{ workflow.active ? $t('CRM.COMMON.ACTIVE') : $t('CRM.COMMON.INACTIVE') }}
                </td>
                <td class="py-4 text-right">
                  <div class="crm-table-actions">
                    <Button
                      variant="link"
                      size="sm"
                      :label="$t('CRM.N8N.RUN')"
                      @click="openExecution(workflow)"
                    />
                  </div>
                </td>
              </tr>
            </template>
          </BaseTable>
          <h3 class="mt-6 text-body-main font-medium text-n-slate-12">
            {{ $t('CRM.N8N.EXECUTIONS') }}
          </h3>
          <BaseTable
            :headers="[
              $t('CRM.N8N.WORKFLOW'),
              $t('CRM.COMMON.STATUS'),
              $t('CRM.N8N.TRIGGER'),
              $t('CRM.N8N.CREATED_AT'),
              $t('CRM.N8N.ERROR'),
            ]"
            :items="executions"
            :no-data-message="$t('CRM.N8N.EXECUTIONS_EMPTY')"
          >
            <template #row="{ items }">
              <tr v-for="execution in items" :key="execution.id">
                <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-12">
                  {{ execution.workflow_id }}
                </td>
                <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
                  {{ execution.status }}
                </td>
                <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
                  {{ execution.trigger }}
                </td>
                <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
                  {{ execution.created_at }}
                </td>
                <td class="py-4 text-body-main text-n-slate-11">
                  {{ execution.error_message || '—' }}
                </td>
              </tr>
            </template>
          </BaseTable>
        </template>
      </div>
      <div class="mt-8 border-t border-n-weak pt-6">
        <h2 class="text-heading-3 text-n-slate-12">
          {{ $t('CRM.N8N.EVENTS') }}
        </h2>
        <div class="grid grid-cols-1 gap-2 mt-3 sm:grid-cols-2 lg:grid-cols-3">
          <span
            v-for="event in events"
            :key="event"
            class="px-3 py-2 text-sm rounded-lg bg-n-alpha-1 text-n-slate-11"
            >{{ event }}</span
          >
        </div>
      </div>
    </template>
    <woot-modal v-model:show="showModal" :on-close="closeModal"
      ><form class="crm-modal-form" @submit.prevent="saveConnection">
        <woot-modal-header
          :header-title="
            selectedConnection
              ? $t('CRM.N8N.EDIT_TITLE')
              : $t('CRM.N8N.CREATE_TITLE')
          "
        /><label
          >{{ $t('CRM.N8N.NAME')
          }}<input v-model.trim="form.name" required /></label
        ><label
          >{{ $t('CRM.N8N.BASE_URL')
          }}<input
            v-model.trim="form.base_url"
            required
            type="url"
            placeholder="http://host.docker.internal:5678" /></label
        ><p class="crm-form-help">
          {{ $t('CRM.N8N.BASE_URL_HELP') }}
        </p>
        ><label
          >{{ $t('CRM.N8N.API_KEY')
          }}<input
            v-model="form.api_key"
            :required="!selectedConnection"
            type="password"
            autocomplete="new-password" /></label
        ><p class="crm-form-help">
          {{ $t('CRM.N8N.API_KEY_HELP') }}
        </p>
        <label>
          {{ $t('CRM.N8N.WEBHOOK_AUTH_HEADER') }}
          <input
            v-model.trim="form.webhook_auth_header"
            autocomplete="off"
            placeholder="Authorization"
          />
        </label>
        <label>
          {{ $t('CRM.N8N.WEBHOOK_AUTH_VALUE') }}
          <input
            v-model="form.webhook_auth_value"
            type="password"
            autocomplete="new-password"
          />
        </label>
        ><label class="crm-form-checkbox"
          ><input v-model="form.active" type="checkbox" />{{
            $t('CRM.COMMON.ACTIVE')
          }}</label
        >
        <div class="crm-form-actions">
          <Button
            variant="faded"
            color="slate"
            :label="$t('CRM.COMMON.CANCEL')"
            type="button"
            @click="closeModal"
          /><Button
            :label="$t('CRM.COMMON.SAVE')"
            :is-loading="isSaving"
            type="submit"
          />
        </div></form
    ></woot-modal>
    <woot-modal v-model:show="showExecutionModal" :on-close="closeExecutionModal">
      <form class="crm-modal-form" @submit.prevent="executeWorkflow">
        <woot-modal-header
          :header-title="$t('CRM.N8N.RUN_TITLE', { name: selectedWorkflow?.name || selectedWorkflow?.id || $t('CRM.N8N.MANUAL') })"
        />
        <label>
          {{ $t('CRM.N8N.WORKFLOW') }}
          <input v-model.trim="executionForm.workflow_id" required />
        </label>
        <label>
          {{ $t('CRM.N8N.WEBHOOK_PATH') }}
          <input
            v-model.trim="executionForm.webhook_path"
            required
            placeholder="webhook-test/webhook"
          />
        </label>
        <p class="crm-form-help">
          {{ $t('CRM.N8N.WEBHOOK_PATH_HELP') }}
        </p>
        <label>
          {{ $t('CRM.N8N.PAYLOAD') }}
          <textarea v-model="executionForm.payload" rows="5" />
        </label>
        <div class="crm-form-actions">
          <Button
            variant="faded"
            color="slate"
            :label="$t('CRM.COMMON.CANCEL')"
            type="button"
            @click="closeExecutionModal"
          />
          <Button
            :label="$t('CRM.N8N.RUN')"
            :is-loading="isSaving"
            type="submit"
          />
        </div>
      </form>
    </woot-modal>
  </section>
</template>
