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
const workflows = ref([]);
const selectedWorkflow = ref(null);
const file = ref(null);
const preview = ref(null);
const isLoading = ref(false);
const isImporting = ref(false);
const showImport = ref(false);

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
    selectedWorkflow.value = data;
    await fetchWorkflows();
    useAlert(t('CRM.WORKFLOWS.IMPORT_SUCCESS'));
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
const openWorkflow = async workflow => {
  try {
    selectedWorkflow.value = (
      await crmAPI.getWorkflow(accountId.value, workflow.id)
    ).data;
  } catch (_) {
    useAlert(t('CRM.WORKFLOWS.FETCH_ERROR'));
  }
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
const report = computed(() => preview.value?.import_report || {});
const nodeLabel = node =>
  node.data?.label || node.data?.name || node.originalType || node.type;
onMounted(fetchWorkflows);
</script>

<template>
  <section>
    <CrmPageHeader
      :title="$t('CRM.WORKFLOWS.TITLE')"
      :description="$t('CRM.WORKFLOWS.DESCRIPTION')"
      :action-label="$t('CRM.WORKFLOWS.IMPORT')"
      action-icon="i-lucide-upload"
      @action="openImport"
    />
    <woot-loading-state v-if="isLoading" :message="$t('CRM.COMMON.LOADING')" />
    <template v-else-if="!selectedWorkflow">
      <BaseTable
        :headers="[
          $t('CRM.WORKFLOWS.NAME'),
          $t('CRM.WORKFLOWS.SOURCE'),
          $t('CRM.WORKFLOWS.NODES'),
          $t('CRM.COMMON.ACTIONS'),
        ]"
        :items="workflows"
        :no-data-message="$t('CRM.WORKFLOWS.EMPTY')"
      >
        <template #row="{ items }">
          <tr v-for="workflow in items" :key="workflow.id">
            <td class="py-4 ltr:pr-4 rtl:pl-4 text-n-slate-12">
              {{ workflow.name }}
            </td>
            <td>{{ workflow.source }}</td>
            <td>{{ workflow.nodes?.length || 0 }}</td>
            <td>
              <Button
                variant="link"
                size="sm"
                :label="$t('CRM.WORKFLOWS.OPEN')"
                @click="openWorkflow(workflow)"
              />
              <Button
                variant="link"
                size="sm"
                :label="$t('CRM.WORKFLOWS.EXPORT')"
                @click="exportWorkflow(workflow)"
              />
            </td>
          </tr>
        </template>
      </BaseTable>
    </template>
    <section v-else class="mt-4">
      <div class="flex items-center justify-between mb-4">
        <div>
          <h2 class="text-lg font-medium text-n-slate-12">
            {{ selectedWorkflow.name }}
          </h2>
          <p class="text-sm text-n-slate-11">
            {{ selectedWorkflow.description }}
          </p>
        </div>
        <Button
          variant="faded"
          color="slate"
          :label="$t('CRM.WORKFLOWS.BACK')"
          @click="selectedWorkflow = null"
        />
        <Button
          variant="faded"
          color="slate"
          :label="$t('CRM.WORKFLOWS.EXPORT')"
          @click="exportWorkflow(selectedWorkflow)"
        />
      </div>
      <div
        class="workflow-canvas"
        :aria-label="$t('CRM.WORKFLOWS.CANVAS_LABEL')"
      >
        <article
          v-for="node in selectedWorkflow.nodes"
          :key="node.id"
          class="workflow-node"
          :class="{
            'workflow-node--warning': node.type === 'unsupported_imported_node',
          }"
          :style="{
            left: `${Math.max(0, node.position?.x || 0)}px`,
            top: `${Math.max(0, node.position?.y || 0)}px`,
          }"
        >
          <strong>{{ nodeLabel(node) }}</strong>
          <small>{{ node.type }}</small>
          <p v-if="node.type === 'unsupported_imported_node'">
            {{
              $t('CRM.WORKFLOWS.WARNING', {
                message: $t('CRM.WORKFLOWS.UNSUPPORTED_NODE', {
                  type: node.originalType,
                }),
              })
            }}
          </p>
          <p v-if="node.data?.requiresCredential">
            {{
              $t('CRM.WORKFLOWS.WARNING', {
                message: $t('CRM.WORKFLOWS.CREDENTIAL_REQUIRED'),
              })
            }}
          </p>
          <p v-if="node.data?.pendingSubflow">
            {{
              $t('CRM.WORKFLOWS.WARNING', {
                message: $t('CRM.WORKFLOWS.SUBFLOW_PENDING', {
                  name: node.data.pendingSubflow,
                }),
              })
            }}
          </p>
        </article>
      </div>
      <p class="mt-3 text-sm text-n-slate-11">
        {{ selectedWorkflow.connections?.length || 0 }}
        {{ $t('CRM.WORKFLOWS.CONNECTIONS') }}
      </p>
    </section>
    <woot-modal v-model:show="showImport" :on-close="closeImport">
      <div class="crm-modal-form">
        <woot-modal-header :header-title="$t('CRM.WORKFLOWS.IMPORT_TITLE')" />
        <p>{{ $t('CRM.WORKFLOWS.IMPORT_HELP') }}</p>
        <input
          accept=".flow,.alvo,.json,application/json"
          type="file"
          @change="selectFile"
        />
        <div v-if="preview" class="workflow-report">
          <h3>{{ preview.name }}</h3>
          <p>{{ $t('CRM.WORKFLOWS.ORIGIN_VALUE', { source: 'EZ.Chat' }) }}</p>
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
  </section>
</template>

<style scoped>
.workflow-canvas {
  position: relative;
  min-height: 580px;
  overflow: auto;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background-image: radial-gradient(
    var(--color-n-slate-5) 1px,
    transparent 1px
  );
  background-size: 20px 20px;
}
.workflow-node {
  position: absolute;
  width: 220px;
  min-height: 88px;
  padding: 12px;
  border: 1px solid var(--color-border);
  border-radius: 8px;
  background: var(--color-n-solid-2);
  box-shadow: var(--shadow-small);
}
.workflow-node strong,
.workflow-node small {
  display: block;
}
.workflow-node small {
  margin-top: 4px;
  color: var(--color-n-slate-10);
}
.workflow-node p {
  margin: 8px 0 0;
  font-size: 12px;
}
.workflow-node--warning {
  border-color: var(--color-ruby-8);
}
.workflow-report {
  margin-top: 16px;
  padding: 12px;
  border-radius: 8px;
  background: var(--color-n-slate-3);
}
.workflow-report p {
  margin: 4px 0;
}
</style>
