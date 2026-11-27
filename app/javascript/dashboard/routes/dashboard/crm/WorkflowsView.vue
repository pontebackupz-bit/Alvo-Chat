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

const isDragging = ref(false);
const isPreviewing = ref(false);

const loadFile = async selected => {
  file.value = selected || null;
  preview.value = null;
  if (!file.value) return;
  isPreviewing.value = true;
  try {
    const { data } = await crmAPI.previewWorkflowImport(
      accountId.value,
      file.value
    );
    preview.value = data;
  } catch (error) {
    useAlert(error.response?.data?.error || t('CRM.WORKFLOWS.PREVIEW_ERROR'), {
      status: 'error',
    });
  } finally {
    isPreviewing.value = false;
  }
};

const selectFile = event => loadFile(event.target.files?.[0]);

const dropFile = event => {
  isDragging.value = false;
  loadFile(event.dataTransfer.files?.[0]);
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

const importStats = computed(() => [
  {
    key: 'nodes',
    label: t('CRM.WORKFLOWS.IMPORT_STATS.NODES'),
    value: report.value.nodesTotal,
  },
  {
    key: 'converted',
    label: t('CRM.WORKFLOWS.IMPORT_STATS.CONVERTED'),
    value: report.value.nodesConverted,
    tone: 'text-n-teal-11',
  },
  {
    key: 'review',
    label: t('CRM.WORKFLOWS.IMPORT_STATS.REVIEW'),
    value: report.value.nodesUnsupported,
    tone: report.value.nodesUnsupported ? 'text-n-amber-11' : '',
  },
  {
    key: 'connections',
    label: t('CRM.WORKFLOWS.IMPORT_STATS.CONNECTIONS'),
    value: report.value.connectionsConverted ?? report.value.connectionsTotal,
  },
  {
    key: 'subflows',
    label: t('CRM.WORKFLOWS.IMPORT_STATS.SUBFLOWS'),
    value: report.value.subflowsPending,
  },
  {
    key: 'credentials',
    label: t('CRM.WORKFLOWS.IMPORT_STATS.CREDENTIALS'),
    value: report.value.credentialsRequired,
  },
]);

// `{ workflow, data }` while the metrics modal is open.
const metrics = ref(null);
const isLoadingMetrics = ref(false);

const openMetrics = async workflow => {
  metrics.value = { workflow, data: null };
  isLoadingMetrics.value = true;
  try {
    const { data } = await crmAPI.getWorkflowMetrics(
      accountId.value,
      workflow.id
    );
    metrics.value = { workflow, data };
  } catch (_) {
    metrics.value = null;
    useAlert(t('CRM.WORKFLOWS.METRICS.FETCH_ERROR'));
  } finally {
    isLoadingMetrics.value = false;
  }
};

const metricCards = computed(() => {
  const data = metrics.value?.data;
  if (!data) return [];
  return [
    { key: 'STARTED', value: data.started },
    { key: 'COMPLETED', value: data.completed, tone: 'text-n-teal-11' },
    { key: 'ABANDONED', value: data.abandoned, tone: 'text-n-amber-11' },
    { key: 'HANDED_OVER', value: data.handed_over },
    { key: 'IN_PROGRESS', value: data.in_progress },
    { key: 'FAILED', value: data.failed, tone: 'text-n-ruby-11' },
  ];
});

const blockName = item => {
  if (item.title) return item.title;
  return item.type
    ? t(`CRM.WORKFLOWS.EDITOR.BLOCKS.${item.type}.LABEL`)
    : t('CRM.WORKFLOWS.METRICS.REMOVED_BLOCK');
};

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
    >
      <template #actions>
        <Button
          icon="i-lucide-upload"
          size="sm"
          variant="faded"
          color="slate"
          :label="$t('CRM.WORKFLOWS.IMPORT')"
          @click="openImport"
        />
      </template>
    </CrmPageHeader>
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
                :label="$t('CRM.WORKFLOWS.METRICS.OPEN')"
                @click="openMetrics(workflow)"
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
        <woot-modal-header
          :header-title="$t('CRM.WORKFLOWS.IMPORT_TITLE')"
          :header-content="$t('CRM.WORKFLOWS.IMPORT_HELP')"
        />
        <label
          class="flex flex-col items-center justify-center gap-2 px-6 py-8 text-center transition-colors border-2 border-dashed cursor-pointer rounded-xl"
          :class="
            isDragging
              ? 'border-n-brand bg-n-brand/10'
              : 'border-n-weak bg-n-alpha-1 hover:border-n-slate-7'
          "
          @dragover.prevent="isDragging = true"
          @dragleave.prevent="isDragging = false"
          @drop.prevent="dropFile"
        >
          <span
            class="flex items-center justify-center rounded-full size-11 bg-n-blue-3 text-n-blue-11"
          >
            <span
              class="size-5"
              :class="file ? 'i-lucide-file-check-2' : 'i-lucide-file-up'"
            />
          </span>
          <span class="text-sm font-medium text-n-slate-12">
            {{ file ? file.name : $t('CRM.WORKFLOWS.IMPORT_DROP') }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{
              file
                ? $t('CRM.WORKFLOWS.IMPORT_CHANGE')
                : $t('CRM.WORKFLOWS.IMPORT_FORMATS')
            }}
          </span>
          <input
            class="sr-only"
            accept=".flow,.alvo,.json,application/json"
            type="file"
            @change="selectFile"
          />
        </label>
        <div
          v-if="isPreviewing"
          class="flex items-center gap-2 text-sm text-n-slate-11"
        >
          <span class="i-lucide-loader-circle size-4 animate-spin" />
          {{ $t('CRM.WORKFLOWS.IMPORT_ANALYSING') }}
        </div>
        <div
          v-if="preview"
          class="flex flex-col gap-4 p-4 border rounded-xl border-n-weak bg-n-solid-2"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
              <h3 class="text-sm font-semibold truncate text-n-slate-12">
                {{ preview.name }}
              </h3>
              <p class="text-xs text-n-slate-11">
                {{
                  $t('CRM.WORKFLOWS.ORIGIN_VALUE', { source: preview.source })
                }}
              </p>
            </div>
            <span
              class="px-2 py-0.5 text-xs font-medium rounded-full shrink-0"
              :class="
                report.nodesUnsupported
                  ? 'bg-n-amber-3 text-n-amber-11'
                  : 'bg-n-teal-3 text-n-teal-11'
              "
            >
              {{
                report.nodesUnsupported
                  ? $t('CRM.WORKFLOWS.IMPORT_NEEDS_REVIEW')
                  : $t('CRM.WORKFLOWS.IMPORT_READY')
              }}
            </span>
          </div>
          <dl class="grid grid-cols-2 gap-2 sm:grid-cols-3">
            <div
              v-for="stat in importStats"
              :key="stat.key"
              class="p-3 rounded-lg bg-n-alpha-1"
            >
              <dt class="text-xs text-n-slate-11">{{ stat.label }}</dt>
              <dd
                class="mt-1 text-lg font-semibold"
                :class="stat.tone || 'text-n-slate-12'"
              >
                {{ stat.value }}
              </dd>
            </div>
          </dl>
          <p class="text-xs leading-relaxed text-n-slate-11">
            {{ $t('CRM.WORKFLOWS.IMPORT_NEXT_STEP') }}
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
            icon="i-lucide-upload"
            :disabled="!preview"
            :is-loading="isImporting"
            :label="$t('CRM.WORKFLOWS.IMPORT')"
            @click="importWorkflow"
          />
        </div>
      </div>
    </woot-modal>

    <woot-modal
      :show="!!metrics"
      :on-close="() => (metrics = null)"
      size="medium"
    >
      <div v-if="metrics" class="flex flex-col gap-5 p-8">
        <woot-modal-header
          :header-title="$t('CRM.WORKFLOWS.METRICS.TITLE')"
          :header-content="
            $t('CRM.WORKFLOWS.METRICS.SUBTITLE', {
              name: metrics.workflow.name,
            })
          "
        />
        <woot-loading-state
          v-if="isLoadingMetrics"
          :message="$t('CRM.COMMON.LOADING')"
        />
        <template v-else-if="metrics.data">
          <div class="grid grid-cols-2 gap-3 sm:grid-cols-3">
            <div
              v-for="card in metricCards"
              :key="card.key"
              class="p-4 border rounded-xl border-n-weak"
            >
              <p class="text-xs text-n-slate-11">
                {{ $t(`CRM.WORKFLOWS.METRICS.${card.key}`) }}
              </p>
              <p
                class="mt-1 text-xl font-semibold"
                :class="card.tone || 'text-n-slate-12'"
              >
                {{ card.value }}
              </p>
            </div>
          </div>
          <div>
            <div class="flex justify-between text-sm">
              <span class="text-n-slate-11">
                {{ $t('CRM.WORKFLOWS.METRICS.COMPLETION_RATE') }}
              </span>
              <span class="font-medium text-n-slate-12">
                {{ `${metrics.data.completion_rate}%` }}
              </span>
            </div>
            <div class="h-2 mt-2 rounded-full bg-n-alpha-2">
              <div
                class="h-full rounded-full bg-n-teal-9"
                :style="{ width: `${metrics.data.completion_rate}%` }"
              />
            </div>
          </div>
          <div>
            <h3 class="text-sm font-medium text-n-slate-12">
              {{ $t('CRM.WORKFLOWS.METRICS.DROP_OFF') }}
            </h3>
            <p class="mt-1 text-xs text-n-slate-11">
              {{ $t('CRM.WORKFLOWS.METRICS.DROP_OFF_HELP') }}
            </p>
            <ul
              v-if="metrics.data.drop_off.length"
              class="mt-3 divide-y divide-n-weak border-y border-n-weak"
            >
              <li
                v-for="item in metrics.data.drop_off"
                :key="item.node_id"
                class="flex items-center justify-between gap-4 py-3 text-sm"
              >
                <div class="min-w-0">
                  <p class="font-medium text-n-slate-12">
                    {{ blockName(item) }}
                  </p>
                  <p v-if="item.preview" class="truncate text-n-slate-11">
                    {{ item.preview }}
                  </p>
                </div>
                <span
                  class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-amber-3 text-n-amber-11 shrink-0"
                >
                  {{
                    $t('CRM.WORKFLOWS.METRICS.CUSTOMERS', { count: item.count })
                  }}
                </span>
              </li>
            </ul>
            <p v-else class="py-6 text-sm text-center text-n-slate-11">
              {{ $t('CRM.WORKFLOWS.METRICS.NO_DROP_OFF') }}
            </p>
          </div>
        </template>
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
