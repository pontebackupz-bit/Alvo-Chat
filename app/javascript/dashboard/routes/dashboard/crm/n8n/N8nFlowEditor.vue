<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import crmAPI from 'dashboard/api/crm';
import FlowCanvas from '../flow/FlowCanvas.vue';
import FlowEditorShell from '../flow/FlowEditorShell.vue';
import FlowHelp from '../flow/FlowHelp.vue';
import {
  NODE_CATALOG,
  buildNode,
  graphToWorkflow,
  isTriggerType,
  nodeAppearance,
  outputLabels,
  shortTypeName,
  uniqueNodeName,
  workflowToGraph,
} from './n8nFlow';

const props = defineProps({
  accountId: { type: [String, Number], required: true },
  connection: { type: Object, required: true },
  // null starts a new workflow.
  workflow: { type: Object, default: null },
});

const emit = defineEmits(['close']);

const { t } = useI18n();

const workflowId = ref(props.workflow?.id || null);
const name = ref(props.workflow?.name || t('CRM.N8N.FLOW.NEW_NAME'));
const active = ref(Boolean(props.workflow?.active));
const settings = ref(props.workflow?.settings || { executionOrder: 'v1' });
const nodes = ref([]);
const edges = ref([]);
const selection = ref(null);
const isDirty = ref(false);
const isSaving = ref(false);
const isToggling = ref(false);
const paramsDraft = ref('');
const paramsError = ref(false);
const canvas = ref(null);

const OUTPUT_TONES = { TRUE: 'green', FALSE: 'red' };

const blocks = NODE_CATALOG.map(block => ({
  key: block.key,
  ...nodeAppearance(block.type),
  label: t(`CRM.N8N.FLOW.BLOCKS.${block.key}.LABEL`),
  description: t(`CRM.N8N.FLOW.BLOCKS.${block.key}.DESCRIPTION`),
}));

const helpSteps = [1, 2, 3, 4, 5].map(step =>
  t(`CRM.N8N.FLOW.HELP_STEPS.${step}`)
);

const nodesById = computed(() =>
  Object.fromEntries(nodes.value.map(node => [node.id, node]))
);
const selectedNode = computed(() =>
  selection.value?.kind === 'node' ? nodesById.value[selection.value.id] : null
);
const selectedEdge = computed(() =>
  selection.value?.kind === 'edge'
    ? edges.value.find(edge => edge.id === selection.value.id)
    : null
);
// The bundled n8n service is reached by Rails as http://n8n:5678, which the
// browser cannot resolve; it is published on the same host at port 5678.
const n8nUrl = computed(() => {
  if (!workflowId.value) return null;
  const url = new URL(props.connection.base_url);
  if (url.hostname === 'n8n') url.hostname = window.location.hostname;
  return `${url.origin}/workflow/${workflowId.value}`;
});

// n8n links are keyed by connection type and output index; the board by handle.
const canvasEdges = computed(() =>
  edges.value.map(edge => ({
    id: edge.id,
    source: edge.source,
    sourceHandle: `${edge.type}:${edge.output}`,
    target: edge.target,
    targetHandle: edge.input,
    vertical: edge.type !== 'main',
  }))
);

const markDirty = () => {
  isDirty.value = true;
};

const outputLabelText = label =>
  label ? t(`CRM.N8N.FLOW.OUTPUTS.${label}`) : '';

const inputCount = node =>
  isTriggerType(node.type)
    ? 0
    : Math.max(
        1,
        ...edges.value
          .filter(edge => edge.target === node.id && edge.type === 'main')
          .map(edge => edge.input + 1)
      );

const describeNode = node => {
  const appearance = nodeAppearance(node.type);
  return {
    ...appearance,
    category: t(`CRM.N8N.FLOW.CATEGORIES.${appearance.category}`),
    title: node.name,
    subtitle: appearance.blockKey
      ? t(`CRM.N8N.FLOW.BLOCKS.${appearance.blockKey}.LABEL`)
      : shortTypeName(node.type),
    disabled: node.disabled,
    inputs: inputCount(node),
    outputs: outputLabels(node, edges.value).map((label, index) => ({
      key: `main:${index}`,
      label: outputLabelText(label),
      tone: OUTPUT_TONES[label] || 'brand',
    })),
  };
};

const connect = ({ source, sourceHandle, target }) => {
  const output = Number(sourceHandle.split(':')[1]);
  const exists = edges.value.some(
    edge =>
      edge.type === 'main' &&
      edge.source === source &&
      edge.output === output &&
      edge.target === target
  );
  if (exists) return;
  edges.value.push({
    id: `${source}-${output}-${target}-${Date.now()}`,
    source,
    output,
    target,
    input: 0,
    type: 'main',
  });
  markDirty();
};

const deleteSelection = () => {
  if (selectedNode.value) {
    const id = selectedNode.value.id;
    nodes.value = nodes.value.filter(node => node.id !== id);
    edges.value = edges.value.filter(
      edge => edge.source !== id && edge.target !== id
    );
  } else if (selectedEdge.value) {
    edges.value = edges.value.filter(edge => edge.id !== selectedEdge.value.id);
  } else {
    return;
  }
  selection.value = null;
  markDirty();
};

const addBlock = (blockKey, position) => {
  const block = NODE_CATALOG.find(item => item.key === blockKey);
  const nodeName = uniqueNodeName(
    t(`CRM.N8N.FLOW.BLOCKS.${block.key}.LABEL`),
    nodes.value
  );
  const node = buildNode(block, nodeName, position);
  nodes.value.push(node);
  selection.value = { kind: 'node', id: node.id };
  markDirty();
};

watch(selectedNode, node => {
  paramsDraft.value = node
    ? JSON.stringify(node.parameters || {}, null, 2)
    : '';
  paramsError.value = false;
});

const renameSelectedNode = event => {
  const node = selectedNode.value;
  const requested = event.target.value.trim();
  if (!requested || requested === node.name) {
    event.target.value = node.name;
    return;
  }
  node.name = uniqueNodeName(requested, nodes.value, node.id);
  event.target.value = node.name;
  markDirty();
};

const toggleSelectedNodeDisabled = event => {
  selectedNode.value.disabled = event.target.checked;
  markDirty();
};

const applyParams = () => {
  try {
    selectedNode.value.parameters = JSON.parse(paramsDraft.value || '{}');
    paramsError.value = false;
    markDirty();
  } catch (_) {
    paramsError.value = true;
  }
};

const edgeDescription = edge => {
  const source = nodesById.value[edge.source];
  const target = nodesById.value[edge.target];
  const output = outputLabelText(
    outputLabels(source, edges.value)[edge.output]
  );
  return t('CRM.N8N.FLOW.EDGE_DESCRIPTION', {
    source: output ? `${source.name} (${output})` : source.name,
    target: target.name,
  });
};

const save = async () => {
  if (!name.value.trim()) {
    useAlert(t('CRM.N8N.FLOW.NAME_REQUIRED'));
    return;
  }
  isSaving.value = true;
  const payload = {
    name: name.value.trim(),
    settings: settings.value,
    ...graphToWorkflow({ nodes: nodes.value, edges: edges.value }),
  };
  try {
    const { data } = workflowId.value
      ? await crmAPI.updateN8nWorkflow(
          props.accountId,
          props.connection.id,
          workflowId.value,
          payload
        )
      : await crmAPI.createN8nWorkflow(
          props.accountId,
          props.connection.id,
          payload
        );
    workflowId.value = data.id;
    active.value = Boolean(data.active);
    isDirty.value = false;
    useAlert(t('CRM.N8N.FLOW.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(error.response?.data?.error || t('CRM.N8N.FLOW.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const toggleActive = async value => {
  isToggling.value = true;
  try {
    const { data } = await crmAPI.setN8nWorkflowActive(
      props.accountId,
      props.connection.id,
      workflowId.value,
      value
    );
    active.value = Boolean(data.active);
  } catch (error) {
    active.value = !value;
    useAlert(error.response?.data?.error || t('CRM.N8N.FLOW.ACTIVATE_ERROR'));
  } finally {
    isToggling.value = false;
  }
};

onMounted(async () => {
  if (props.workflow) {
    const graph = workflowToGraph(props.workflow);
    nodes.value = graph.nodes;
    edges.value = graph.edges;
  }
  await nextTick();
  canvas.value.fitView();
});
</script>

<template>
  <FlowEditorShell
    v-model:name="name"
    :is-dirty="isDirty"
    :is-saving="isSaving"
    :save-label="$t('CRM.COMMON.SAVE')"
    @edit="markDirty"
    @save="save"
    @close="emit('close')"
  >
    <template #actions>
      <label
        v-if="workflowId"
        v-tooltip="isDirty ? $t('CRM.N8N.FLOW.SAVE_BEFORE_ACTIVATE') : ''"
        class="flex items-center gap-2 text-sm text-n-slate-11"
        :class="{ 'opacity-50 pointer-events-none': isDirty || isToggling }"
      >
        <Switch :model-value="active" @update:model-value="toggleActive" />
        {{ active ? $t('CRM.COMMON.ACTIVE') : $t('CRM.COMMON.INACTIVE') }}
      </label>
      <a
        v-if="n8nUrl"
        :href="n8nUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="flex items-center gap-1 text-sm text-n-slate-11 hover:text-n-slate-12"
      >
        <span class="i-lucide-external-link size-4" />
        {{ $t('CRM.N8N.FLOW.OPEN_IN_N8N') }}
      </a>
    </template>

    <FlowCanvas
      ref="canvas"
      v-model:selection="selection"
      :nodes="nodes"
      :edges="canvasEdges"
      :describe-node="describeNode"
      :blocks="blocks"
      @add-block="addBlock"
      @connect="connect"
      @delete-selection="deleteSelection"
      @moved="markDirty"
    >
      <template #paletteHint>
        {{ $t('CRM.N8N.FLOW.PALETTE_HINT') }}
      </template>
    </FlowCanvas>

    <template #sidebar>
      <template v-if="selectedNode">
        <div class="flex items-center gap-3">
          <span
            class="flex items-center justify-center rounded-lg size-9"
            :class="nodeAppearance(selectedNode.type).tint"
          >
            <span
              class="size-4"
              :class="nodeAppearance(selectedNode.type).icon"
            />
          </span>
          <div class="min-w-0">
            <p class="text-xs text-n-slate-11">
              {{ describeNode(selectedNode).category }}
            </p>
            <p class="text-xs truncate text-n-slate-10">
              {{ selectedNode.type }}
            </p>
          </div>
        </div>
        <label class="flex flex-col gap-1.5 text-sm text-n-slate-12">
          {{ $t('CRM.N8N.FLOW.NODE_NAME') }}
          <input
            :key="selectedNode.id"
            :value="selectedNode.name"
            class="px-3 text-sm rounded-lg h-9 bg-n-alpha-black2 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12"
            @change="renameSelectedNode"
          />
        </label>
        <label class="flex items-center gap-2 text-sm text-n-slate-12">
          <input
            type="checkbox"
            :checked="Boolean(selectedNode.disabled)"
            @change="toggleSelectedNodeDisabled"
          />
          {{ $t('CRM.N8N.FLOW.NODE_DISABLED') }}
        </label>
        <label class="flex flex-col gap-1.5 text-sm text-n-slate-12">
          {{ $t('CRM.N8N.FLOW.NODE_PARAMETERS') }}
          <textarea
            v-model="paramsDraft"
            rows="12"
            spellcheck="false"
            class="p-3 font-mono text-xs rounded-lg resize-y bg-n-alpha-black2 outline outline-1 focus:outline-n-brand text-n-slate-12"
            :class="paramsError ? 'outline-n-ruby-9' : 'outline-n-weak'"
            @blur="applyParams"
          />
        </label>
        <p v-if="paramsError" class="-mt-2 text-xs text-n-ruby-11">
          {{ $t('CRM.N8N.FLOW.PARAMETERS_ERROR') }}
        </p>
        <p class="-mt-2 text-xs text-n-slate-11">
          {{ $t('CRM.N8N.FLOW.PARAMETERS_HELP') }}
        </p>
        <Button
          icon="i-lucide-trash-2"
          color="ruby"
          variant="faded"
          size="sm"
          :label="$t('CRM.N8N.FLOW.DELETE_NODE')"
          @click="deleteSelection"
        />
      </template>

      <template v-else-if="selectedEdge">
        <h3 class="text-sm font-semibold text-n-slate-12">
          {{ $t('CRM.N8N.FLOW.EDGE_TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11">
          {{ edgeDescription(selectedEdge) }}
        </p>
        <Button
          icon="i-lucide-trash-2"
          color="ruby"
          variant="faded"
          size="sm"
          :label="$t('CRM.N8N.FLOW.DELETE_EDGE')"
          @click="deleteSelection"
        />
      </template>

      <FlowHelp
        v-else
        :steps="helpSteps"
        :note="$t('CRM.N8N.FLOW.HELP_NOTE')"
      />
    </template>
  </FlowEditorShell>
</template>
