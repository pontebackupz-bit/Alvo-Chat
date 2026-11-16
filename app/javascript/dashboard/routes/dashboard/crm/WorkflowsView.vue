<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { BaseTable } from 'dashboard/components-next/table';
import Button from 'dashboard/components-next/button/Button.vue';
import crmAPI from 'dashboard/api/crm';
import CrmPageHeader from './CrmPageHeader.vue';
import ChatbotFlowEditor from './flow/ChatbotFlowEditor.vue';

const { t } = useI18n();
const route = useRoute();
const accountId = computed(() => route.params.accountId);
const inboxes = useMapGetter('inboxes/getInboxes');
const workflows = ref([]);
const file = ref(null);
const preview = ref(null);
const isLoading = ref(false);
const isImporting = ref(false);
const showImport = ref(false);
// `{ workflow: null }` opens the editor for a new flow.
const editor = ref(null);

const fetchWorkflows = async () => {
  isLoading.value = true;
  try {
    const { data } = await crmAPI.getWorkflows(accountId.value);
    workflows.value = Array.isArray(data) ? data : data.workflows || [];
  } catch (_) {
    useAlert(t('CRM.WORKFLOWS.FETCH_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const openEditor = async workflow => {
  if (!workflow) {
    editor.value = { workflow: null };
    return;
  }
  try {
    const { data } = await crmAPI.getWorkflow(accountId.value, workflow.id);
    editor.value = { workflow: data };
  } catch (_) {
    useAlert(t('CRM.WORKFLOWS.FETCH_ERROR'));
  }
};

const closeEditor = () => {
  editor.value = null;
  fetchWorkflows();
};

const deleteWorkflow = async workflow => {
  try {
    await crmAPI.deleteWorkflow(accountId.value, workflow.id);
    useAlert(t('CRM.WORKFLOWS.DELETE_SUCCESS'));
    await fetchWorkflows();
  } catch (_) {
    useAlert(t('CRM.WORKFLOWS.DELETE_ERROR'));
  }
};

const selectFile = async event => {
  file.value = event.target.files?.[0] || null;
  preview.value = null;
  if (!file.value) return;
  try {
    const { data } = await crmAPI.previewWorkflowImport(
      accountId.value,
      file.value
    );
    preview.value = data;
  } catch (error) {
    useAlert(error.response?.data?.error || t('CRM.WORKFLOWS.PREVIEW_ERROR'));
  }
};

const importWorkflow = async () => {
  if (!file.value) return;
  isImporting.value = true;
  try {
    const { data } = await crmAPI.importWorkflow(accountId.value, file.value);
    showImport.value = false;
    await fetchWorkflows();
    useAlert(t('CRM.WORKFLOWS.IMPORT_SUCCESS'));
    editor.value = { workflow: data };
  } catch (error) {
    useAlert(error.response?.data?.error || t('CRM.WORKFLOWS.IMPORT_ERROR'));
  } finally {
    isImporting.value = false;
  }
};

const openImport = () => {
  file.value = null;
  preview.value = null;
  showImport.value = true;
};

const closeImport = () => {
  showImport.value = false;
  file.value = null;
  preview.value = null;
};

const exportWorkflow = async workflow => {
  try {
    const { data } = await crmAPI.exportWorkflow(accountId.value, workflow.id);
    const url = URL.createObjectURL(data);
    const link = document.createElement('a');
    link.href = url;
    link.download = `${workflow.name || `workflow-${workflow.id}`}.alvo`;
    link.click();
    URL.revokeObjectURL(url);
  } catch (_) {
    useAlert(t('CRM.WORKFLOWS.EXPORT_ERROR'));
  }
};

const triggerLabel = workflow => {
  const ids = workflow.trigger_config?.inbox_ids || [];
  const names = ids.length
    ? inboxes.value
        .filter(inbox => ids.includes(inbox.id))
        .map(inbox => inbox.name)
        .join(', ')
    : t('CRM.WORKFLOWS.EDITOR.ALL_INBOXES');
  return t('CRM.WORKFLOWS.TRIGGER_NEW_CONVERSATION', { inboxes: names });
};

const report = computed(() => preview.value?.import_report || {});

onMounted(fetchWorkflows);
</script>

<template>
  <section>
    <CrmPageHeader
      :title="$t('CRM.WORKFLOWS.TITLE')"
      :description="$t('CRM.WORKFLOWS.DESCRIPTION')"
      :action-label="$t('CRM.WORKFLOWS.NEW')"
      action-icon="i-lucide-plus"
      @action="openEditor()"
    />
    <div class="flex justify-end -mt-2 mb-4">
      <Button
        icon="i-lucide-upload"
        size="sm"
        variant="faded"
        color="slate"
        :label="$t('CRM.WORKFLOWS.IMPORT')"
        @click="openImport"
      />
    </div>
    <woot-loading-state v-if="isLoading" :message="$t('CRM.COMMON.LOADING')" />
    <BaseTable
      v-else
      :headers="[
        $t('CRM.WORKFLOWS.NAME'),
        $t('CRM.COMMON.STATUS'),
        $t('CRM.WORKFLOWS.TRIGGER'),
        $t('CRM.WORKFLOWS.NODES'),
        $t('CRM.COMMON.ACTIONS'),
      ]"
      :items="workflows"
      :no-data-message="$t('CRM.WORKFLOWS.EMPTY')"
    >
      <template #row="{ items }">
        <tr v-for="workflow in items" :key="workflow.id">
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-12">
            {{ workflow.name }}
          </td>
          <td class="py-4 ltr:pr-4 rtl:pl-4">
            <span
              class="inline-flex items-center gap-1.5 px-2 py-0.5 text-xs font-medium rounded-full"
              :class="
                workflow.active
                  ? 'bg-n-teal-3 text-n-teal-11'
                  : 'bg-n-alpha-2 text-n-slate-11'
              "
            >
              <span
                class="rounded-full size-1.5"
                :class="workflow.active ? 'bg-n-teal-9' : 'bg-n-slate-9'"
              />
              {{
                workflow.active
                  ? $t('CRM.COMMON.ACTIVE')
                  : $t('CRM.COMMON.INACTIVE')
              }}
            </span>
          </td>
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
            {{ triggerLabel(workflow) }}
          </td>
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
            {{ workflow.nodes?.length || 0 }}
          </td>
          <td class="py-4 text-right">
            <div class="crm-table-actions">
              <Button
                variant="link"
                size="sm"
                :label="$t('CRM.WORKFLOWS.OPEN')"
                @click="openEditor(workflow)"
              />
              <Button
                variant="link"
                size="sm"
                :label="$t('CRM.WORKFLOWS.EXPORT')"
                @click="exportWorkflow(workflow)"
              />
              <Button
                variant="link"
                color="ruby"
                size="sm"
                :label="$t('CRM.COMMON.DELETE')"
                @click="deleteWorkflow(workflow)"
              />
            </div>
          </td>
        </tr>
      </template>
    </BaseTable>

    <woot-modal v-model:show="showImport" :on-close="closeImport">
      <div class="crm-modal-form">
        <woot-modal-header :header-title="$t('CRM.WORKFLOWS.IMPORT_TITLE')" />
        <p>{{ $t('CRM.WORKFLOWS.IMPORT_HELP') }}</p>
        <input
          accept=".flow,.alvo,.json,application/json"
          type="file"
          @change="selectFile"
        />
        <div
          v-if="preview"
          class="flex flex-col gap-1 p-3 text-sm rounded-lg bg-n-alpha-1 text-n-slate-11"
        >
          <h3 class="font-medium text-n-slate-12">{{ preview.name }}</h3>
          <p>
            {{ $t('CRM.WORKFLOWS.ORIGIN_VALUE', { source: preview.source }) }}
          </p>
          <p>
            {{ report.nodesTotal }} {{ $t('CRM.WORKFLOWS.NODES') }} ·
            {{ report.connectionsTotal }} {{ $t('CRM.WORKFLOWS.CONNECTIONS') }}
          </p>
          <p>
            {{ report.nodesConverted }} {{ $t('CRM.WORKFLOWS.CONVERTED') }} ·
            {{ report.nodesUnsupported }} {{ $t('CRM.WORKFLOWS.NEEDS_REVIEW') }}
          </p>
          <p>
            {{ report.credentialsRequired }}
            {{ $t('CRM.WORKFLOWS.CREDENTIALS') }} ·
            {{ report.subflowsPending }} {{ $t('CRM.WORKFLOWS.SUBFLOWS') }}
          </p>
        </div>
        <div class="crm-form-actions">
          <Button
            variant="faded"
            color="slate"
            :label="$t('CRM.COMMON.CANCEL')"
            @click="closeImport"
          />
          <Button
            :disabled="!preview"
            :is-loading="isImporting"
            :label="$t('CRM.WORKFLOWS.IMPORT')"
            @click="importWorkflow"
          />
        </div>
      </div>
    </woot-modal>

    <ChatbotFlowEditor
      v-if="editor"
      :account-id="accountId"
      :workflow="editor.workflow"
      @close="closeEditor"
    />
  </section>
</template>
