<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import crmAPI from 'dashboard/api/crm';
import CrmPageHeader from './CrmPageHeader.vue';

const { t } = useI18n();
const route = useRoute();
const accountId = computed(() => route.params.accountId);
const isLoading = ref(false);
const period = ref(30);
const teamId = ref('');
const periods = [7, 30, 90];
const metrics = ref({
  leads: 0,
  open_conversations: 0,
  resolved_conversations: 0,
  conversions: 0,
  conversion_rate: 0,
  average_first_response_seconds: null,
  unanswered_conversations: 0,
  awaiting_reply: 0,
  sellers: [],
  teams: [],
  channels: {},
  available_teams: [],
});

const percentage = value =>
  `${Number(value || 0).toLocaleString(undefined, { maximumFractionDigits: 2 })}%`;
const duration = value => {
  if (value == null) return '—';
  const minutes = Math.round(value / 60);
  if (minutes < 60) return t('CRM.DASHBOARD.MINUTES', { count: minutes });
  return t('CRM.DASHBOARD.HOURS', {
    count: (minutes / 60).toLocaleString(undefined, {
      maximumFractionDigits: 1,
    }),
  });
};

const cards = computed(() => [
  {
    label: t('CRM.DASHBOARD.OPEN'),
    value: metrics.value.open_conversations,
    icon: 'i-lucide-messages-square',
  },
  {
    label: t('CRM.DASHBOARD.RESOLVED'),
    value: metrics.value.resolved_conversations,
    icon: 'i-lucide-circle-check',
  },
  {
    label: t('CRM.DASHBOARD.AVG_RESPONSE'),
    value: duration(metrics.value.average_first_response_seconds),
    icon: 'i-lucide-timer',
  },
  {
    label: t('CRM.DASHBOARD.LEADS'),
    value: metrics.value.leads,
    icon: 'i-lucide-user-plus',
  },
  {
    label: t('CRM.DASHBOARD.CONVERSIONS'),
    value: metrics.value.conversions,
    hint: percentage(metrics.value.conversion_rate),
    icon: 'i-lucide-trophy',
  },
]);

const alerts = computed(() => [
  {
    label: t('CRM.DASHBOARD.UNANSWERED'),
    help: t('CRM.DASHBOARD.UNANSWERED_HELP'),
    value: metrics.value.unanswered_conversations,
  },
  {
    label: t('CRM.DASHBOARD.AWAITING_REPLY'),
    help: t('CRM.DASHBOARD.AWAITING_REPLY_HELP'),
    value: metrics.value.awaiting_reply,
  },
]);

const channels = computed(() => Object.entries(metrics.value.channels || {}));
const maxChannel = computed(() =>
  Math.max(1, ...channels.value.map(([, value]) => value))
);
const teamName = team => team.name || t('CRM.DASHBOARD.NO_TEAM');

const fetchMetrics = async () => {
  isLoading.value = true;
  try {
    const startAt = new Date(Date.now() - period.value * 24 * 60 * 60 * 1000);
    const { data } = await crmAPI.getDashboardMetrics(accountId.value, {
      start_at: startAt.toISOString(),
      team_id: teamId.value || undefined,
    });
    metrics.value = { ...metrics.value, ...data };
  } catch (error) {
    useAlert(t('CRM.DASHBOARD.FETCH_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

watch([period, teamId], fetchMetrics);
onMounted(fetchMetrics);
</script>

<template>
  <section>
    <CrmPageHeader
      :title="$t('CRM.DASHBOARD.TITLE')"
      :description="$t('CRM.DASHBOARD.DESCRIPTION')"
    />

    <div class="flex flex-wrap items-center gap-3 mt-4">
      <div class="inline-flex p-1 rounded-lg bg-n-alpha-2">
        <button
          v-for="days in periods"
          :key="days"
          type="button"
          class="px-3 py-1 text-sm rounded-md transition-colors"
          :class="
            period === days
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm font-medium'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="period = days"
        >
          {{ $t('CRM.DASHBOARD.LAST_DAYS', { count: days }) }}
        </button>
      </div>
      <select
        v-if="metrics.available_teams.length"
        v-model="teamId"
        class="!mb-0 !w-auto min-w-48 !h-9 !py-1 text-sm rounded-lg"
      >
        <option value="">{{ $t('CRM.DASHBOARD.ALL_TEAMS') }}</option>
        <option
          v-for="team in metrics.available_teams"
          :key="team.id"
          :value="team.id"
        >
          {{ team.name }}
        </option>
      </select>
    </div>

    <woot-loading-state v-if="isLoading" :message="$t('CRM.COMMON.LOADING')" />
    <template v-else>
      <div class="grid gap-4 mt-6 sm:grid-cols-2 xl:grid-cols-5">
        <article
          v-for="card in cards"
          :key="card.label"
          class="p-5 border rounded-xl border-n-weak bg-n-solid-1"
        >
          <div class="flex items-center gap-2 text-sm text-n-slate-11">
            <span :class="card.icon" class="size-4" />
            {{ card.label }}
          </div>
          <p class="mt-3 text-2xl font-semibold text-n-slate-12">
            {{ card.value }}
          </p>
          <p v-if="card.hint" class="mt-1 text-xs text-n-slate-11">
            {{ $t('CRM.DASHBOARD.CONVERSION_RATE') }} {{ card.hint }}
          </p>
        </article>
      </div>

      <div class="grid gap-4 mt-4 sm:grid-cols-2">
        <article
          v-for="alert in alerts"
          :key="alert.label"
          class="flex items-center justify-between gap-4 p-5 border rounded-xl"
          :class="
            alert.value
              ? 'border-n-amber-6 bg-n-amber-2'
              : 'border-n-weak bg-n-solid-1'
          "
        >
          <div>
            <p class="text-sm font-medium text-n-slate-12">{{ alert.label }}</p>
            <p class="mt-1 text-xs text-n-slate-11">{{ alert.help }}</p>
          </div>
          <p
            class="text-3xl font-semibold"
            :class="alert.value ? 'text-n-amber-11' : 'text-n-slate-12'"
          >
            {{ alert.value }}
          </p>
        </article>
      </div>

      <article class="mt-8">
        <h2 class="text-heading-3 text-n-slate-12">
          {{ $t('CRM.DASHBOARD.SELLERS') }}
        </h2>
        <div class="mt-3 overflow-x-auto border rounded-xl border-n-weak">
          <table class="w-full text-sm">
            <thead class="bg-n-alpha-1 text-n-slate-11">
              <tr>
                <th class="px-4 py-3 font-medium text-left">
                  {{ $t('CRM.DASHBOARD.SELLER') }}
                </th>
                <th class="px-4 py-3 font-medium text-right">
                  {{ $t('CRM.DASHBOARD.CONVERSATIONS') }}
                </th>
                <th class="px-4 py-3 font-medium text-right">
                  {{ $t('CRM.DASHBOARD.RESOLVED_SHORT') }}
                </th>
                <th class="px-4 py-3 font-medium text-right">
                  {{ $t('CRM.DASHBOARD.OPEN_NOW') }}
                </th>
                <th class="px-4 py-3 font-medium text-right">
                  {{ $t('CRM.DASHBOARD.FIRST_RESPONSE') }}
                </th>
                <th class="px-4 py-3 font-medium text-right">
                  {{ $t('CRM.DASHBOARD.CONVERSIONS') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak">
              <tr v-for="(seller, index) in metrics.sellers" :key="seller.id">
                <td class="px-4 py-3 text-n-slate-12">
                  <span
                    class="inline-flex items-center justify-center mr-2 text-xs font-semibold rounded-full size-6"
                    :class="
                      index < 3
                        ? 'bg-n-blue-3 text-n-blue-11'
                        : 'bg-n-alpha-2 text-n-slate-11'
                    "
                  >
                    {{ index + 1 }}
                  </span>
                  {{ seller.name }}
                </td>
                <td class="px-4 py-3 text-right text-n-slate-12">
                  {{ seller.conversations }}
                </td>
                <td class="px-4 py-3 text-right text-n-slate-11">
                  {{ seller.resolved }}
                </td>
                <td class="px-4 py-3 text-right text-n-slate-11">
                  {{ seller.open }}
                </td>
                <td class="px-4 py-3 text-right text-n-slate-11">
                  {{ duration(seller.average_first_response_seconds) }}
                </td>
                <td class="px-4 py-3 text-right text-n-slate-11">
                  {{ seller.conversions }}
                </td>
              </tr>
              <tr v-if="!metrics.sellers.length">
                <td colspan="6" class="py-8 text-center text-n-slate-11">
                  {{ $t('CRM.DASHBOARD.EMPTY') }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </article>

      <div class="grid gap-6 mt-8 lg:grid-cols-2">
        <article>
          <h2 class="text-heading-3 text-n-slate-12">
            {{ $t('CRM.DASHBOARD.TEAMS') }}
          </h2>
          <ul class="mt-3 divide-y divide-n-weak border-y border-n-weak">
            <li
              v-for="team in metrics.teams"
              :key="team.id || 'none'"
              class="flex justify-between py-3 text-sm"
            >
              <span class="text-n-slate-11">{{ teamName(team) }}</span>
              <span class="font-medium text-n-slate-12">
                {{
                  $t('CRM.DASHBOARD.TEAM_VALUE', {
                    total: team.conversations,
                    resolved: team.resolved,
                  })
                }}
              </span>
            </li>
            <li
              v-if="!metrics.teams.length"
              class="py-8 text-sm text-center text-n-slate-11"
            >
              {{ $t('CRM.DASHBOARD.EMPTY') }}
            </li>
          </ul>
        </article>
        <article>
          <h2 class="text-heading-3 text-n-slate-12">
            {{ $t('CRM.DASHBOARD.CHANNELS') }}
          </h2>
          <ul class="mt-3 space-y-3">
            <li v-for="[name, value] in channels" :key="name" class="text-sm">
              <div class="flex justify-between">
                <span class="text-n-slate-11">{{ name }}</span>
                <span class="font-medium text-n-slate-12">{{ value }}</span>
              </div>
              <div class="h-1.5 mt-1.5 rounded-full bg-n-alpha-2">
                <div
                  class="h-full rounded-full bg-n-blue-9"
                  :style="{ width: `${(value / maxChannel) * 100}%` }"
                />
              </div>
            </li>
            <li
              v-if="!channels.length"
              class="py-8 text-sm text-center text-n-slate-11"
            >
              {{ $t('CRM.DASHBOARD.EMPTY') }}
            </li>
          </ul>
        </article>
      </div>
    </template>
  </section>
</template>
