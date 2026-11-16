<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import crmAPI from 'dashboard/api/crm';
import FlowCanvas from './FlowCanvas.vue';
import FlowEditorShell from './FlowEditorShell.vue';
import FlowHelp from './FlowHelp.vue';
import {
  BLOCKS,
  CONDITION_OPERATORS,
  CONTACT_VARIABLES,
  appearance,
  buildNode,
  connectionId,
  isKnownType,
  newOption,
  outputsFor,
  starterFlow,
  validateFlow,
} from './chatbotFlow';

const props = defineProps({
  accountId: { type: [String, Number], required: true },
  // null starts a new flow.
  workflow: { type: Object, default: null },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const variablePlaceholder = 'cidade';
const store = useStore();
const inboxes = useMapGetter('inboxes/getInboxes');
const teams = useMapGetter('teams/getTeams');
const agents = useMapGetter('agents/getAgents');
const labels = useMapGetter('labels/getLabels');

const workflowId = ref(props.workflow?.id || null);
const name = ref(props.workflow?.name || t('CRM.WORKFLOWS.EDITOR.NEW_NAME'));
const active = ref(Boolean(props.workflow?.active));
const triggerConfig = ref({
  type: 'conversation_created',
  inbox_ids: [],
  ...(props.workflow?.trigger_config || {}),
});
const nodes = ref([]);
const connections = ref([]);
const selection = ref(null);
const isDirty = ref(false);
const isSaving = ref(false);
const canvas = ref(null);

const field =
  'w-full px-3 py-2 text-sm rounded-lg bg-n-alpha-black2 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12';
const fieldLabel = 'flex flex-col gap-1.5 text-sm font-medium text-n-slate-12';

const blockLabel = type =>
  isKnownType(type) ? t(`CRM.WORKFLOWS.EDITOR.BLOCKS.${type}.LABEL`) : type;

const blocks = BLOCKS.map(block => ({
  key: block.type,
  ...appearance(block.type),
  label: blockLabel(block.type),
  description: t(`CRM.WORKFLOWS.EDITOR.BLOCKS.${block.type}.DESCRIPTION`),
}));

const helpSteps = [1, 2, 3, 4, 5].map(step =>
  t(`CRM.WORKFLOWS.EDITOR.HELP_STEPS.${step}`)
);

const nodesById = computed(() =>
  Object.fromEntries(nodes.value.map(node => [node.id, node]))
);
const selectedNode = computed(() =>
  selection.value?.kind === 'node' ? nodesById.value[selection.value.id] : null
);
const selectedEdge = computed(() =>
  selection.value?.kind === 'edge'
    ? connections.value.find(item => item.id === selection.value.id)
    : null
);

const selectedInboxNames = computed(() => {
  const ids = triggerConfig.value.inbox_ids || [];
  if (!ids.length) return t('CRM.WORKFLOWS.EDITOR.ALL_INBOXES');
  return inboxes.value
    .filter(inbox => ids.includes(inbox.id))
    .map(inbox => inbox.name)
    .join(', ');
});
const subtitle = computed(() =>
  t('CRM.WORKFLOWS.EDITOR.SUBTITLE', { inboxes: selectedInboxNames.value })
);

const variables = computed(() => [
  'resposta',
  ...CONTACT_VARIABLES,
  ...nodes.value
    .filter(node => node.type === 'ask_question' && node.data.variable)
    .map(node => node.data.variable),
]);

const variableToken = variable => `{{${variable}}}`;

const outputLabel = output =>
  output.labelKey
    ? t(`CRM.WORKFLOWS.EDITOR.OUTPUTS.${output.labelKey}`)
    : output.label;

const truncate = text =>
  text && text.length > 70 ? `${text.slice(0, 70)}…` : text;

const nameById = (list, id) => list.find(item => item.id === id)?.name;

const summary = node => {
  const { data = {} } = node;
  const summaries = {
    start: () => selectedInboxNames.value,
    send_message: () => truncate(data.content),
    ask_question: () => truncate(data.content),
    menu: () =>
      t('CRM.WORKFLOWS.EDITOR.SUMMARY.OPTIONS', {
        count: (data.options || []).length,
      }),
    condition: () =>
      `${data.variable} · ${t(`CRM.WORKFLOWS.EDITOR.OPERATORS.${data.operator}`)} ${data.value || ''}`,
    wait: () =>
      t('CRM.WORKFLOWS.EDITOR.SUMMARY.MINUTES', { count: data.minutes }),
    add_label: () => (data.labels || []).join(', '),
    transfer_team: () => nameById(teams.value, data.team_id),
    assign_agent: () => nameById(agents.value, data.agent_id),
    end: () =>
      data.resolve
        ? t('CRM.WORKFLOWS.EDITOR.SUMMARY.RESOLVES')
        : t('CRM.WORKFLOWS.EDITOR.SUMMARY.ENDS'),
  };
  return (
    summaries[node.type]?.() ||
    t(
      isKnownType(node.type)
        ? 'CRM.WORKFLOWS.EDITOR.SUMMARY.EMPTY'
        : 'CRM.WORKFLOWS.EDITOR.SUMMARY.UNSUPPORTED'
    )
  );
};

const describeNode = node => {
  const look = appearance(node.type);
  return {
    ...look,
    category: blockLabel(node.type),
    title:
      node.type === 'start'
        ? t('CRM.WORKFLOWS.EDITOR.START_TITLE')
        : node.data?.title || blockLabel(node.type),
    subtitle: summary(node),
    inputs: node.type === 'start' ? 0 : 1,
    outputs: outputsFor(node, connections.value).map(output => ({
      ...output,
      label: outputLabel(output),
    })),
  };
};

const canvasEdges = computed(() =>
  connections.value.map(connection => ({
    ...connection,
    sourceHandle: connection.sourceHandle || 'next',
  }))
);

// Each output leads to one place, so a new link replaces the previous one.
const connect = ({ source, sourceHandle, target }) => {
  connections.value = [
    ...connections.value.filter(
      item =>
        !(
          item.source === source &&
          (item.sourceHandle || 'next') === sourceHandle
        )
    ),
    { id: connectionId(), source, sourceHandle, target },
  ];
};

const removeNode = id => {
  nodes.value = nodes.value.filter(node => node.id !== id);
  connections.value = connections.value.filter(
    item => item.source !== id && item.target !== id
  );
};

const deleteSelection = () => {
  if (selectedNode.value && selectedNode.value.type !== 'start') {
    removeNode(selectedNode.value.id);
  } else if (selectedEdge.value) {
    connections.value = connections.value.filter(
      item => item.id !== selectedEdge.value.id
    );
  } else {
    return;
  }
  selection.value = null;
};

const addBlock = (type, position) => {
  const node = buildNode(type, position);
  nodes.value.push(node);
  selection.value = { kind: 'node', id: node.id };
};

const addOption = () => {
  selectedNode.value.data.options.push(newOption());
};

// Removing an option also removes the link leaving from its output.
const removeOption = option => {
  const node = selectedNode.value;
  node.data.options = node.data.options.filter(item => item.id !== option.id);
  connections.value = connections.value.filter(
    item =>
      !(item.source === node.id && item.sourceHandle === `option:${option.id}`)
  );
};

const toggleInbox = inboxId => {
  const ids = triggerConfig.value.inbox_ids || [];
  triggerConfig.value.inbox_ids = ids.includes(inboxId)
    ? ids.filter(id => id !== inboxId)
    : [...ids, inboxId];
};

const toggleLabel = title => {
  const current = selectedNode.value.data.labels || [];
  selectedNode.value.data.labels = current.includes(title)
    ? current.filter(item => item !== title)
    : [...current, title];
};

const edgeDescription = edge => {
  const source = nodesById.value[edge.source];
  const target = nodesById.value[edge.target];
  const output = describeNode(source).outputs.find(
    item => item.key === (edge.sourceHandle || 'next')
  );
  const sourceTitle = describeNode(source).title;
  return t('CRM.WORKFLOWS.EDITOR.EDGE_DESCRIPTION', {
    source: output?.label ? `${sourceTitle} (${output.label})` : sourceTitle,
    target: describeNode(target).title,
  });
};

const save = async () => {
  if (!name.value.trim()) {
    useAlert(t('CRM.WORKFLOWS.EDITOR.NAME_REQUIRED'));
    return;
  }
  const [problem] = active.value ? validateFlow(nodes.value) : [];
  if (problem) {
    selection.value = { kind: 'node', id: problem.nodeId };
    useAlert(t(`CRM.WORKFLOWS.EDITOR.PROBLEMS.${problem.key}`));
    return;
  }
  isSaving.value = true;
  const payload = {
    name: name.value.trim(),
    active: active.value,
    trigger_config: triggerConfig.value,
    nodes: nodes.value,
    connections: connections.value,
  };
  try {
    const { data } = workflowId.value
      ? await crmAPI.updateWorkflow(props.accountId, workflowId.value, payload)
      : await crmAPI.createWorkflow(props.accountId, payload);
    workflowId.value = data.id;
    await nextTick();
    isDirty.value = false;
    useAlert(t('CRM.WORKFLOWS.EDITOR.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('CRM.WORKFLOWS.EDITOR.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

onMounted(async () => {
  ['inboxes/get', 'teams/get', 'agents/get', 'labels/get'].forEach(action =>
    store.dispatch(action)
  );
  const graph = props.workflow
    ? {
        nodes: props.workflow.nodes || [],
        connections: props.workflow.connections || [],
      }
    : starterFlow(t('CRM.WORKFLOWS.EDITOR.STARTER_GREETING'));
  nodes.value = graph.nodes.map(node => ({
    ...node,
    data: node.data || {},
    position: {
      x: Number(node.position?.x) || 0,
      y: Number(node.position?.y) || 0,
    },
  }));
  connections.value = graph.connections;
  isDirty.value = !props.workflow;
  await nextTick();
  canvas.value.fitView();
  watch(
    [nodes, connections, triggerConfig, active, name],
    () => {
      isDirty.value = true;
    },
    { deep: true }
  );
});
</script>

<template>
  <FlowEditorShell
    v-model:name="name"
    :subtitle="subtitle"
    :is-dirty="isDirty"
    :is-saving="isSaving"
    :save-label="$t('CRM.WORKFLOWS.EDITOR.SAVE')"
    @save="save"
    @close="emit('close')"
  >
    <template #actions>
      <label class="flex items-center gap-2 text-sm text-n-slate-11">
        <Switch v-model="active" />
        {{ active ? $t('CRM.COMMON.ACTIVE') : $t('CRM.COMMON.INACTIVE') }}
      </label>
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
    >
      <template #paletteHint>
        {{ $t('CRM.WORKFLOWS.EDITOR.PALETTE_HINT_START') }}
        <span class="text-n-teal-11">
          {{ $t('CRM.WORKFLOWS.EDITOR.OUTPUTS.TRUE') }}
        </span>
        {{ $t('CRM.WORKFLOWS.EDITOR.PALETTE_HINT_OR') }}
        <span class="text-n-ruby-11">
          {{ $t('CRM.WORKFLOWS.EDITOR.OUTPUTS.FALSE') }}
        </span>
        {{ $t('CRM.WORKFLOWS.EDITOR.PALETTE_HINT_END') }}
      </template>
    </FlowCanvas>

    <template #sidebar>
      <template v-if="selectedNode">
        <div class="flex items-center gap-3">
          <span
            class="flex items-center justify-center rounded-lg size-10"
            :class="appearance(selectedNode.type).tint"
          >
            <span class="size-5" :class="appearance(selectedNode.type).icon" />
          </span>
          <div class="min-w-0">
            <p class="text-sm font-semibold text-n-slate-12">
              {{ describeNode(selectedNode).title }}
            </p>
            <p class="text-xs text-n-slate-11">
              {{ blockLabel(selectedNode.type) }}
            </p>
          </div>
        </div>

        <template v-if="selectedNode.type === 'start'">
          <p class="text-sm text-n-slate-11">
            {{ $t('CRM.WORKFLOWS.EDITOR.START_HELP') }}
          </p>
          <fieldset class="flex flex-col gap-2">
            <legend class="mb-2 text-sm font-medium text-n-slate-12">
              {{ $t('CRM.WORKFLOWS.EDITOR.INBOXES') }}
            </legend>
            <label
              v-for="inbox in inboxes"
              :key="inbox.id"
              class="flex items-center gap-2 text-sm text-n-slate-12"
            >
              <input
                type="checkbox"
                :checked="(triggerConfig.inbox_ids || []).includes(inbox.id)"
                @change="toggleInbox(inbox.id)"
              />
              {{ inbox.name }}
            </label>
            <p class="text-xs text-n-slate-11">
              {{ $t('CRM.WORKFLOWS.EDITOR.INBOXES_HELP') }}
            </p>
          </fieldset>
        </template>

        <template
          v-if="isKnownType(selectedNode.type) && selectedNode.type !== 'start'"
        >
          <label :class="fieldLabel">
            {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.TITLE') }}
            <input
              v-model="selectedNode.data.title"
              :class="field"
              :placeholder="blockLabel(selectedNode.type)"
            />
          </label>
        </template>

        <template
          v-if="
            ['send_message', 'ask_question', 'menu'].includes(selectedNode.type)
          "
        >
          <label :class="fieldLabel">
            {{
              $t(
                selectedNode.type === 'send_message'
                  ? 'CRM.WORKFLOWS.EDITOR.FIELDS.MESSAGE'
                  : 'CRM.WORKFLOWS.EDITOR.FIELDS.QUESTION'
              )
            }}
            <textarea
              v-model="selectedNode.data.content"
              rows="5"
              :class="field"
              class="resize-y"
            />
          </label>
          <p class="-mt-2 text-xs text-n-slate-11">
            {{ $t('CRM.WORKFLOWS.EDITOR.VARIABLES_HELP') }}
            <code
              v-for="variable in variables"
              :key="variable"
              class="mr-1 rounded bg-n-alpha-2 px-1 text-n-slate-12"
              >{{ variableToken(variable) }}</code
            >
          </p>
        </template>

        <label v-if="selectedNode.type === 'ask_question'" :class="fieldLabel">
          {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.SAVE_AS') }}
          <input
            v-model.trim="selectedNode.data.variable"
            :class="field"
            :placeholder="variablePlaceholder"
          />
        </label>

        <template v-if="selectedNode.type === 'menu'">
          <div class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.OPTIONS') }}
            </span>
            <div
              v-for="(option, index) in selectedNode.data.options"
              :key="option.id"
              class="flex items-center gap-2"
            >
              <span class="w-5 text-xs text-right text-n-slate-11">
                {{ index + 1 }}.
              </span>
              <input v-model="option.label" :class="field" />
              <Button
                icon="i-lucide-x"
                color="slate"
                variant="ghost"
                size="xs"
                @click="removeOption(option)"
              />
            </div>
            <Button
              icon="i-lucide-plus"
              color="slate"
              variant="faded"
              size="xs"
              :label="$t('CRM.WORKFLOWS.EDITOR.FIELDS.ADD_OPTION')"
              @click="addOption"
            />
            <p class="text-xs text-n-slate-11">
              {{ $t('CRM.WORKFLOWS.EDITOR.MENU_HELP') }}
            </p>
          </div>
        </template>

        <template v-if="selectedNode.type === 'condition'">
          <label :class="fieldLabel">
            {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.VARIABLE') }}
            <select v-model="selectedNode.data.variable" :class="field">
              <option
                v-for="variable in variables"
                :key="variable"
                :value="variable"
              >
                {{ variable }}
              </option>
            </select>
          </label>
          <label :class="fieldLabel">
            {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.OPERATOR') }}
            <select v-model="selectedNode.data.operator" :class="field">
              <option
                v-for="operator in CONDITION_OPERATORS"
                :key="operator"
                :value="operator"
              >
                {{ $t(`CRM.WORKFLOWS.EDITOR.OPERATORS.${operator}`) }}
              </option>
            </select>
          </label>
          <label
            v-if="['contains', 'equals'].includes(selectedNode.data.operator)"
            :class="fieldLabel"
          >
            {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.VALUE') }}
            <input v-model="selectedNode.data.value" :class="field" />
          </label>
        </template>

        <label v-if="selectedNode.type === 'wait'" :class="fieldLabel">
          {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.MINUTES') }}
          <input
            v-model.number="selectedNode.data.minutes"
            type="number"
            min="1"
            :class="field"
          />
        </label>

        <fieldset
          v-if="selectedNode.type === 'add_label'"
          class="flex flex-col gap-2"
        >
          <legend class="mb-2 text-sm font-medium text-n-slate-12">
            {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.LABELS') }}
          </legend>
          <label
            v-for="label in labels"
            :key="label.id"
            class="flex items-center gap-2 text-sm text-n-slate-12"
          >
            <input
              type="checkbox"
              :checked="(selectedNode.data.labels || []).includes(label.title)"
              @change="toggleLabel(label.title)"
            />
            {{ label.title }}
          </label>
          <p v-if="!labels.length" class="text-xs text-n-slate-11">
            {{ $t('CRM.WORKFLOWS.EDITOR.NO_LABELS') }}
          </p>
        </fieldset>

        <label v-if="selectedNode.type === 'transfer_team'" :class="fieldLabel">
          {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.TEAM') }}
          <select v-model="selectedNode.data.team_id" :class="field">
            <option :value="null" disabled>
              {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.CHOOSE') }}
            </option>
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ team.name }}
            </option>
          </select>
        </label>

        <label v-if="selectedNode.type === 'assign_agent'" :class="fieldLabel">
          {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.AGENT') }}
          <select v-model="selectedNode.data.agent_id" :class="field">
            <option :value="null" disabled>
              {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.CHOOSE') }}
            </option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </label>

        <label
          v-if="selectedNode.type === 'end'"
          class="flex items-center gap-2 text-sm text-n-slate-12"
        >
          <input v-model="selectedNode.data.resolve" type="checkbox" />
          {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.RESOLVE') }}
        </label>

        <p
          v-if="!isKnownType(selectedNode.type)"
          class="p-3 text-xs border rounded-lg border-n-ruby-6 text-n-ruby-11"
        >
          {{ $t('CRM.WORKFLOWS.EDITOR.PROBLEMS.UNSUPPORTED') }}
        </p>

        <Button
          v-if="selectedNode.type !== 'start'"
          icon="i-lucide-trash-2"
          color="ruby"
          variant="faded"
          size="sm"
          :label="$t('CRM.WORKFLOWS.EDITOR.DELETE_NODE')"
          @click="deleteSelection"
        />
      </template>

      <template v-else-if="selectedEdge">
        <h3 class="text-sm font-semibold text-n-slate-12">
          {{ $t('CRM.WORKFLOWS.EDITOR.EDGE_TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11">
          {{ edgeDescription(selectedEdge) }}
        </p>
        <Button
          icon="i-lucide-trash-2"
          color="ruby"
          variant="faded"
          size="sm"
          :label="$t('CRM.WORKFLOWS.EDITOR.DELETE_EDGE')"
          @click="deleteSelection"
        />
      </template>

      <FlowHelp
        v-else
        :steps="helpSteps"
        :note="$t('CRM.WORKFLOWS.EDITOR.HELP_NOTE')"
      />
    </template>
  </FlowEditorShell>
</template>
