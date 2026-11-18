<script setup>
// Status card shown by useAlert(). The status comes from `action.status`
// ('success' | 'error' | 'warning' | 'info') or, for the many existing
// alerts that do not pass one, from the wording of the message.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  message: { type: String, default: '' },
  action: { type: Object, default: () => ({}) },
  duration: { type: Number, default: 2500 },
});

const emit = defineEmits(['close']);

const { t } = useI18n();

const PATTERNS = [
  [
    'error',
    /(erro|error|não foi possível|nao foi possivel|falh|fail|could not|couldn't|unable|inválid|invalid|negad|denied|expirad)/i,
  ],
  [
    'warning',
    /(atenção|atencao|aviso|warning|obrigatóri|required|selecione|informe|preencha|limite|excede)/i,
  ],
  [
    'success',
    /(sucesso|success|salv|saved|criad|created|atualizad|updated|removid|removed|excluíd|deleted|enviad|sent|copiad|copied|conectad|connected|importad|imported|adicionad|added|ativad|concluíd)/i,
  ],
];

const STYLES = {
  success: {
    icon: 'i-lucide-circle-check',
    badge: 'bg-n-teal-3 text-n-teal-11',
    bar: 'bg-n-teal-9',
  },
  error: {
    icon: 'i-lucide-circle-x',
    badge: 'bg-n-ruby-3 text-n-ruby-11',
    bar: 'bg-n-ruby-9',
  },
  warning: {
    icon: 'i-lucide-triangle-alert',
    badge: 'bg-n-amber-3 text-n-amber-11',
    bar: 'bg-n-amber-9',
  },
  info: {
    icon: 'i-lucide-info',
    badge: 'bg-n-blue-3 text-n-blue-11',
    bar: 'bg-n-blue-9',
  },
};

const status = computed(() => {
  if (STYLES[props.action?.status]) return props.action.status;
  return (
    PATTERNS.find(([, pattern]) => pattern.test(props.message))?.[0] || 'info'
  );
});
const style = computed(() => STYLES[status.value]);
const title = computed(() =>
  t(`GENERAL_SETTINGS.STATUS_CARD.${status.value.toUpperCase()}`)
);
</script>

<template>
  <div
    class="relative flex items-start w-full gap-3 p-4 mb-3 overflow-hidden text-left border shadow-lg rounded-xl border-n-weak bg-n-solid-2"
    role="status"
    :aria-live="status === 'error' ? 'assertive' : 'polite'"
  >
    <span
      class="flex items-center justify-center rounded-full size-8 shrink-0"
      :class="style.badge"
    >
      <span class="size-4" :class="style.icon" />
    </span>
    <div class="flex flex-col flex-1 min-w-0 gap-0.5 pt-0.5">
      <p class="text-sm font-semibold text-n-slate-12">{{ title }}</p>
      <p class="text-sm break-words text-n-slate-11">{{ message }}</p>
      <router-link
        v-if="action?.type == 'link'"
        :to="action.to"
        class="mt-1 text-sm font-medium cursor-pointer select-none text-n-blue-11 hover:text-n-brand"
      >
        {{ action.message }}
      </router-link>
    </div>
    <button
      type="button"
      class="flex items-center justify-center rounded-md size-6 shrink-0 text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
      :aria-label="$t('GENERAL_SETTINGS.STATUS_CARD.CLOSE')"
      @click="emit('close')"
    >
      <span class="i-lucide-x size-4" />
    </button>
    <span
      class="absolute bottom-0 left-0 h-0.5 status-card-timer"
      :class="style.bar"
      :style="{ animationDuration: `${duration}ms` }"
    />
  </div>
</template>

<style scoped>
.status-card-timer {
  width: 100%;
  animation-name: status-card-countdown;
  animation-timing-function: linear;
  animation-fill-mode: forwards;
}

@keyframes status-card-countdown {
  from {
    width: 100%;
  }

  to {
    width: 0;
  }
}
</style>
