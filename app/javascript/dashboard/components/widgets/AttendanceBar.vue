<script setup>
// Top of the conversation list: live counters, search by protocol / name /
// phone, and the Ativos / Atrasados / Pausados views.
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import crmAPI from 'dashboard/api/crm';

const props = defineProps({
  // 'active' | 'late' | 'paused' | '' (another status picked in the header)
  view: { type: String, default: 'active' },
  search: { type: String, default: '' },
});

const emit = defineEmits(['update:view', 'update:search']);

const REFRESH_MS = 30000;
const SEARCH_DELAY_MS = 400;

const { t } = useI18n();
const accountId = useMapGetter('getCurrentAccountId');
const stats = ref(null);
const term = ref(props.search);
let refreshTimer = null;
let searchTimer = null;

const fetchStats = async () => {
  try {
    const { data } = await crmAPI.getAttendanceStats(accountId.value);
    stats.value = data;
  } catch (_) {
    // Counters are informative; the list keeps working without them.
  }
};

const counters = computed(() => {
  const data = stats.value || {};
  return [
    {
      key: 'resolved',
      icon: 'i-lucide-circle-check',
      tone: 'text-n-teal-11',
      value: data.resolved_today,
      tip: t('ATTENDANCE.COUNTERS.RESOLVED'),
    },
    {
      key: 'agents',
      icon: 'i-lucide-users-round',
      tone: 'text-n-iris-11',
      value: data.agents_online,
      tip: t('ATTENDANCE.COUNTERS.AGENTS'),
    },
    {
      key: 'late',
      icon: 'i-lucide-clock',
      tone: 'text-n-amber-11',
      value: data.late,
      tip: t('ATTENDANCE.COUNTERS.LATE', {
        minutes: data.late_after_minutes || 15,
      }),
    },
    {
      key: 'active',
      icon: 'i-lucide-message-circle-more',
      tone: 'text-n-blue-11',
      value: data.active,
      tip: t('ATTENDANCE.COUNTERS.ACTIVE'),
    },
  ];
});

const views = computed(() => {
  const data = stats.value || {};
  return [
    { key: 'active', count: data.active, label: t('ATTENDANCE.VIEWS.ACTIVE') },
    { key: 'late', count: data.late, label: t('ATTENDANCE.VIEWS.LATE') },
    { key: 'paused', count: data.snoozed, label: t('ATTENDANCE.VIEWS.PAUSED') },
  ];
});

const onSearchInput = () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(
    () => emit('update:search', term.value.trim()),
    SEARCH_DELAY_MS
  );
};

const clearSearch = () => {
  term.value = '';
  emit('update:search', '');
};

watch(
  () => props.search,
  value => {
    if (value !== term.value.trim()) term.value = value;
  }
);

onMounted(() => {
  fetchStats();
  refreshTimer = setInterval(fetchStats, REFRESH_MS);
});

onBeforeUnmount(() => {
  clearInterval(refreshTimer);
  clearTimeout(searchTimer);
});

defineExpose({ refresh: fetchStats });
</script>

<template>
  <div class="flex flex-col gap-3 px-4 pt-1 pb-2">
    <div
      class="flex items-center justify-between px-3 py-2 border rounded-lg border-n-weak bg-n-solid-1"
    >
      <template v-for="(counter, index) in counters" :key="counter.key">
        <span v-if="index" class="w-px h-4 bg-n-weak" />
        <span
          v-tooltip.bottom="counter.tip"
          class="flex items-center gap-1.5 text-sm font-semibold text-n-slate-12 cursor-default"
        >
          <span class="size-4" :class="[counter.icon, counter.tone]" />
          {{ counter.value ?? '–' }}
        </span>
      </template>
    </div>

    <div class="relative">
      <span
        class="absolute -translate-y-1/2 pointer-events-none i-lucide-search size-4 left-3 top-1/2 text-n-slate-10"
      />
      <input
        v-model="term"
        type="search"
        class="!mb-0 !h-9 !pl-9 !pr-8 w-full text-sm rounded-lg"
        :placeholder="$t('ATTENDANCE.SEARCH_PLACEHOLDER')"
        @input="onSearchInput"
        @keydown.esc="clearSearch"
      />
      <button
        v-if="term"
        type="button"
        class="absolute -translate-y-1/2 right-2 top-1/2 flex items-center justify-center rounded size-6 text-n-slate-10 hover:text-n-slate-12"
        :aria-label="$t('ATTENDANCE.CLEAR_SEARCH')"
        @click="clearSearch"
      >
        <span class="i-lucide-x size-3.5" />
      </button>
    </div>

    <div class="flex gap-1 overflow-x-auto no-scrollbar">
      <button
        v-for="item in views"
        :key="item.key"
        type="button"
        class="flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium rounded-md whitespace-nowrap transition-colors"
        :class="
          view === item.key
            ? 'bg-n-brand/15 text-n-blue-11'
            : 'text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
        "
        @click="emit('update:view', item.key)"
      >
        {{ item.label }}
        <span
          class="px-1.5 rounded-full text-[11px]"
          :class="view === item.key ? 'bg-n-brand/20' : 'bg-n-alpha-2'"
        >
          {{ item.count ?? 0 }}
        </span>
      </button>
    </div>
  </div>
</template>
