<script setup>
// Side panel fields of the blocks that carry logic or come from imported
// flows (EZ.Chat): conditions with several rules, variables, A/B split,
// inactivity, subflows, the human handover options, code, integrations and
// notes. The node's data is edited in place.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  QUESTION_VALIDATORS,
  RULE_OPERATORS,
  UNARY_OPERATORS,
  newRule,
} from './chatbotFlow';

const props = defineProps({
  node: { type: Object, required: true },
  workflows: { type: Array, default: () => [] },
});

const { t } = useI18n();

const field =
  'w-full px-3 py-2 text-sm rounded-lg bg-n-alpha-black2 outline outline-1 outline-n-weak focus:outline-n-brand text-n-slate-12';
const fieldLabel = 'flex flex-col gap-1.5 text-sm font-medium text-n-slate-12';
const sectionTitle = 'text-sm font-medium text-n-slate-12';
const help = 'text-xs text-n-slate-11';
const placeholders = {
  left: '{{flow.setor}}',
  right: 'comercial',
  key: 'setor',
  value: '{{input.setor}}',
  data: '{ "tipo": "horario" }',
};

const data = computed(() => props.node.data);
const integrationName = computed(() =>
  t(
    `CRM.WORKFLOWS.EDITOR.INTEGRATIONS.${data.value.provider === 'oracle' ? 'ORACLE' : 'GOOGLE_SHEETS'}`
  )
);

const variableRows = computed(() => Object.entries(data.value.values || {}));

const setVariable = (index, key, value) => {
  const rows = [...variableRows.value];
  rows[index] = [key, value];
  data.value.values = Object.fromEntries(rows);
};

const addVariable = () => {
  data.value.values = { ...(data.value.values || {}), '': '' };
};

const removeVariable = index => {
  data.value.values = Object.fromEntries(
    variableRows.value.filter((_, rowIndex) => rowIndex !== index)
  );
};

const addRule = () => {
  data.value.rules = [...(data.value.rules || []), newRule()];
};

const removeRule = rule => {
  data.value.rules = data.value.rules.filter(item => item.id !== rule.id);
};

const addSplit = () => {
  const ids = (data.value.splits || []).map(split => split.id);
  const next = 'abcdefghij'.split('').find(id => !ids.includes(id));
  if (next)
    data.value.splits = [
      ...ids.map((_, i) => data.value.splits[i]),
      { id: next, value: 0 },
    ];
};

const splitTotal = computed(() =>
  (data.value.splits || []).reduce(
    (sum, split) => sum + Number(split.value || 0),
    0
  )
);

const subflowNames = computed(() =>
  props.workflows
    .filter(workflow => workflow.name)
    .map(workflow => workflow.name)
);
const subflowMissing = computed(
  () =>
    data.value.flow_name &&
    !subflowNames.value.some(
      name =>
        name.trim().toLowerCase() === data.value.flow_name.trim().toLowerCase()
    )
);

const toggle = key => {
  data.value[key] = !data.value[key];
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- Typed answers -->
    <template v-if="node.type === 'ask_question'">
      <label :class="fieldLabel">
        {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.VALIDATOR') }}
        <select v-model="data.validator" :class="field">
          <option
            v-for="validator in QUESTION_VALIDATORS"
            :key="validator"
            :value="validator || undefined"
          >
            {{ $t(`CRM.WORKFLOWS.EDITOR.VALIDATORS.${validator || 'any'}`) }}
          </option>
        </select>
      </label>
      <template v-if="data.validator">
        <label :class="fieldLabel">
          {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.RETRIES') }}
          <input
            v-model.number="data.retries"
            type="number"
            min="0"
            :class="field"
          />
        </label>
        <label :class="fieldLabel">
          {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.RETRY_MESSAGE') }}
          <textarea
            v-model="data.retry_message"
            rows="3"
            :class="field"
            class="resize-y"
          />
        </label>
      </template>
    </template>

    <!-- Rules -->
    <div v-if="node.type === 'branch'" class="flex flex-col gap-3">
      <span :class="sectionTitle">
        {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.RULES') }}
      </span>
      <div
        v-for="(rule, index) in data.rules"
        :key="rule.id"
        class="flex flex-col gap-2 p-3 border rounded-lg border-n-weak bg-n-alpha-1"
      >
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold text-n-slate-11">
            {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.RULE', { number: index + 1 }) }}
          </span>
          <Button
            icon="i-lucide-x"
            color="slate"
            variant="ghost"
            size="xs"
            @click="removeRule(rule)"
          />
        </div>
        <input
          v-model="rule.left"
          :class="field"
          :placeholder="placeholders.left"
        />
        <select v-model="rule.operator" :class="field">
          <option
            v-for="operator in RULE_OPERATORS"
            :key="operator"
            :value="operator"
          >
            {{ $t(`CRM.WORKFLOWS.EDITOR.RULE_OPERATORS.${operator}`) }}
          </option>
        </select>
        <input
          v-if="!UNARY_OPERATORS.includes(rule.operator)"
          v-model="rule.right"
          :class="field"
          :placeholder="placeholders.right"
        />
      </div>
      <Button
        icon="i-lucide-plus"
        color="slate"
        variant="faded"
        size="xs"
        :label="$t('CRM.WORKFLOWS.EDITOR.FIELDS.ADD_RULE')"
        @click="addRule"
      />
      <p :class="help">{{ $t('CRM.WORKFLOWS.EDITOR.RULES_HELP') }}</p>
    </div>

    <!-- Variables -->
    <template v-if="node.type === 'set_variables'">
      <label :class="fieldLabel">
        {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.SCOPE') }}
        <select v-model="data.scope" :class="field">
          <option value="flow">
            {{ $t('CRM.WORKFLOWS.EDITOR.SCOPES.flow') }}
          </option>
          <option value="contact">
            {{ $t('CRM.WORKFLOWS.EDITOR.SCOPES.contact') }}
          </option>
        </select>
      </label>
      <div class="flex flex-col gap-2">
        <span :class="sectionTitle">
          {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.VALUES') }}
        </span>
        <div
          v-for="([key, value], index) in variableRows"
          :key="index"
          class="grid grid-cols-[1fr_1fr_auto] gap-2"
        >
          <input
            :value="key"
            :class="field"
            :placeholder="placeholders.key"
            @change="setVariable(index, $event.target.value.trim(), value)"
          />
          <input
            :value="typeof value === 'string' ? value : JSON.stringify(value)"
            :class="field"
            :placeholder="placeholders.value"
            @change="setVariable(index, key, $event.target.value)"
          />
          <Button
            icon="i-lucide-x"
            color="slate"
            variant="ghost"
            size="xs"
            @click="removeVariable(index)"
          />
        </div>
        <Button
          icon="i-lucide-plus"
          color="slate"
          variant="faded"
          size="xs"
          :label="$t('CRM.WORKFLOWS.EDITOR.FIELDS.ADD_VARIABLE')"
          @click="addVariable"
        />
        <p :class="help">{{ $t('CRM.WORKFLOWS.EDITOR.EXPRESSIONS_HELP') }}</p>
      </div>
    </template>

    <!-- A/B split -->
    <div v-if="node.type === 'split'" class="flex flex-col gap-2">
      <span :class="sectionTitle">
        {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.SPLITS') }}
      </span>
      <div
        v-for="split in data.splits"
        :key="split.id"
        class="flex items-center gap-2"
      >
        <span
          class="flex items-center justify-center text-xs font-semibold rounded-md size-8 shrink-0 bg-n-amber-3 text-n-amber-11"
        >
          {{ String(split.id).toUpperCase() }}
        </span>
        <input
          v-model.number="split.value"
          type="number"
          min="0"
          max="100"
          :class="field"
        />
      </div>
      <Button
        icon="i-lucide-plus"
        color="slate"
        variant="faded"
        size="xs"
        :label="$t('CRM.WORKFLOWS.EDITOR.FIELDS.ADD_SPLIT')"
        @click="addSplit"
      />
      <p :class="[help, { '!text-n-ruby-11': splitTotal !== 100 }]">
        {{ $t('CRM.WORKFLOWS.EDITOR.SPLIT_TOTAL', { total: splitTotal }) }}
      </p>
    </div>

    <!-- Inactivity -->
    <template v-if="node.type === 'inactivity'">
      <label :class="fieldLabel">
        {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.INACTIVITY_MINUTES') }}
        <input
          v-model.number="data.minutes"
          type="number"
          min="1"
          :class="field"
        />
      </label>
      <p :class="help">{{ $t('CRM.WORKFLOWS.EDITOR.INACTIVITY_HELP') }}</p>
    </template>

    <!-- Subflow -->
    <template v-if="node.type === 'subflow'">
      <label :class="fieldLabel">
        {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.SUBFLOW') }}
        <input
          v-model="data.flow_name"
          :class="field"
          list="crm-flow-subflows"
        />
        <datalist id="crm-flow-subflows">
          <option v-for="name in subflowNames" :key="name" :value="name" />
        </datalist>
      </label>
      <p
        v-if="subflowMissing"
        class="p-3 -mt-2 text-xs rounded-lg bg-n-amber-2 text-n-amber-11"
      >
        {{ $t('CRM.WORKFLOWS.EDITOR.SUBFLOW_MISSING') }}
      </p>
      <label :class="fieldLabel">
        {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.SUBFLOW_DATA') }}
        <textarea
          v-model="data.data"
          rows="4"
          :class="field"
          class="font-mono text-xs resize-y"
          :placeholder="placeholders.data"
        />
      </label>
      <label class="flex items-start gap-2 text-sm text-n-slate-12">
        <input
          class="mt-0.5"
          type="checkbox"
          :checked="data.returns"
          @change="toggle('returns')"
        />
        <span>
          {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.RETURNS') }}
          <span class="block text-xs text-n-slate-11">
            {{ $t('CRM.WORKFLOWS.EDITOR.RETURNS_HELP') }}
          </span>
        </span>
      </label>
    </template>

    <!-- Human handover options -->
    <template v-if="node.type === 'transfer_team'">
      <p
        v-if="!data.team_id && data.team_name"
        class="p-3 text-xs rounded-lg bg-n-alpha-2 text-n-slate-11"
      >
        {{ $t('CRM.WORKFLOWS.EDITOR.IMPORTED_TEAM', { name: data.team_name }) }}
      </p>
      <label class="flex items-start gap-2 text-sm text-n-slate-12">
        <input
          class="mt-0.5"
          type="checkbox"
          :checked="data.wait_for_agent"
          @change="toggle('wait_for_agent')"
        />
        <span>
          {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.WAIT_FOR_AGENT') }}
          <span class="block text-xs text-n-slate-11">
            {{ $t('CRM.WORKFLOWS.EDITOR.WAIT_FOR_AGENT_HELP') }}
          </span>
        </span>
      </label>
    </template>

    <template v-if="node.type === 'assign_agent'">
      <label v-if="!data.agent_id" :class="fieldLabel">
        {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.AGENT_EMAIL') }}
        <input v-model.trim="data.agent_email" :class="field" />
      </label>
      <label class="flex items-start gap-2 text-sm text-n-slate-12">
        <input
          class="mt-0.5"
          type="checkbox"
          :checked="data.only_if_online"
          @change="toggle('only_if_online')"
        />
        <span>
          {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.ONLY_IF_ONLINE') }}
          <span class="block text-xs text-n-slate-11">
            {{ $t('CRM.WORKFLOWS.EDITOR.ONLY_IF_ONLINE_HELP') }}
          </span>
        </span>
      </label>
    </template>

    <!-- Imported, read-only blocks -->
    <template v-if="node.type === 'code'">
      <p :class="help">{{ $t('CRM.WORKFLOWS.EDITOR.CODE_HELP') }}</p>
      <pre
        class="p-3 overflow-auto text-xs rounded-lg max-h-64 bg-n-alpha-black2 text-n-slate-12"
        >{{ data.code }}</pre
      >
    </template>

    <template v-if="node.type === 'integration'">
      <p class="p-3 text-xs rounded-lg bg-n-amber-2 text-n-amber-11">
        {{
          $t('CRM.WORKFLOWS.EDITOR.INTEGRATION_HELP', {
            name: integrationName,
          })
        }}
      </p>
      <pre
        v-if="data.query || data.payload"
        class="p-3 overflow-auto text-xs rounded-lg max-h-64 bg-n-alpha-black2 text-n-slate-12"
        >{{ data.query || data.payload }}</pre
      >
    </template>

    <label v-if="node.type === 'note'" :class="fieldLabel">
      {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.NOTE') }}
      <textarea v-model="data.text" rows="6" :class="field" class="resize-y" />
    </label>

    <!-- Media sent before the text -->
    <div
      v-if="
        ['send_message', 'ask_question', 'menu'].includes(node.type) &&
        data.attachments?.length
      "
      class="flex flex-col gap-2"
    >
      <span :class="sectionTitle">
        {{ $t('CRM.WORKFLOWS.EDITOR.FIELDS.ATTACHMENTS') }}
      </span>
      <a
        v-for="attachment in data.attachments"
        :key="attachment.url"
        :href="attachment.url"
        target="_blank"
        rel="noopener noreferrer"
        class="flex items-center gap-2 p-2 text-xs truncate border rounded-lg border-n-weak text-n-blue-11 hover:bg-n-alpha-1"
      >
        <span
          class="size-4 shrink-0"
          :class="
            attachment.type === 'image'
              ? 'i-lucide-image'
              : 'i-lucide-paperclip'
          "
        />
        <span class="truncate">{{ attachment.url }}</span>
      </a>
    </div>
  </div>
</template>
