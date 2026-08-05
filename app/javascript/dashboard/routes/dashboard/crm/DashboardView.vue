<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import crmAPI from 'dashboard/api/crm';
import CrmPageHeader from './CrmPageHeader.vue';

const { t } = useI18n();
const route = useRoute();
const accountId = computed(() => route.params.accountId);
const isLoading = ref(false);
const metrics = ref({
  leads: 0,
  open_conversations: 0,
  resolved_conversations: 0,
  conversions: 0,
  conversion_rate: 0,
  average_first_response_seconds: null,
  sellers: {},
  teams: {},
  channels: {},
});
const cards = computed(() => [
  { label: t('CRM.DASHBOARD.LEADS'), value: metrics.value.leads },
  { label: t('CRM.DASHBOARD.OPEN'), value: metrics.value.open_conversations },
  {
    label: t('CRM.DASHBOARD.RESOLVED'),
    value: metrics.value.resolved_conversations,
  },
  { label: t('CRM.DASHBOARD.CONVERSIONS'), value: metrics.value.conversions },
]);
const fetchMetrics = async () => {
  isLoading.value = true;
  try {
    const { data } = await crmAPI.getDashboardMetrics(accountId.value);
    metrics.value = { ...metrics.value, ...data };
  } catch (error) {
    useAlert(t('CRM.DASHBOARD.FETCH_ERROR'));
  } finally {
    isLoading.value = false;
  }
};
const percentage = value =>
  `${Number(value || 0).toLocaleString(undefined, { maximumFractionDigits: 2 })}%`;
const duration = value =>
  value == null ? '—' : `${Math.round(value / 60)} min`;
const entries = metric => Object.entries(metric || {});
onMounted(fetchMetrics);
</script>

<template>
  <section>
    <CrmPageHeader
      :title="$t('CRM.DASHBOARD.TITLE')"
      :description="$t('CRM.DASHBOARD.DESCRIPTION')"
    />
    <woot-loading-state v-if="isLoading" :message="$t('CRM.COMMON.LOADING')" />
    <template v-else
      ><div class="grid gap-4 mt-6 sm:grid-cols-2 xl:grid-cols-4">
        <article
          v-for="card in cards"
          :key="card.label"
          class="p-5 border rounded-xl border-n-weak"
        >
          <p class="text-sm text-n-slate-11">{{ card.label }}</p>
          <p class="mt-2 text-2xl font-semibold text-n-slate-12">
            {{ card.value }}
          </p>
        </article>
      </div>
      <div class="grid gap-4 mt-4 sm:grid-cols-2">
        <article class="p-5 border rounded-xl border-n-weak">
          <p class="text-sm text-n-slate-11">
            {{ $t('CRM.DASHBOARD.CONVERSION_RATE') }}
          </p>
          <p class="mt-2 text-2xl font-semibold text-n-slate-12">
            {{ percentage(metrics.conversion_rate) }}
          </p>
        </article>
        <article class="p-5 border rounded-xl border-n-weak">
          <p class="text-sm text-n-slate-11">
            {{ $t('CRM.DASHBOARD.AVG_RESPONSE') }}
          </p>
          <p class="mt-2 text-2xl font-semibold text-n-slate-12">
            {{ duration(metrics.average_first_response_seconds) }}
          </p>
        </article>
      </div>
      <div class="grid gap-6 mt-8 lg:grid-cols-3">
        <article
          v-for="section in [
            { key: 'sellers', label: $t('CRM.DASHBOARD.SELLERS') },
            { key: 'teams', label: $t('CRM.DASHBOARD.TEAMS') },
            { key: 'channels', label: $t('CRM.DASHBOARD.CHANNELS') },
          ]"
          :key="section.key"
        >
          <h2 class="text-heading-3 text-n-slate-12">{{ section.label }}</h2>
          <ul class="mt-3 divide-y divide-n-weak border-y border-n-weak">
            <li
              v-for="[name, value] in entries(metrics[section.key])"
              :key="name"
              class="flex justify-between py-3 text-sm"
            >
              <span class="text-n-slate-11">{{ name }}</span
              ><span class="font-medium text-n-slate-12">{{ value }}</span>
            </li>
            <li
              v-if="!entries(metrics[section.key]).length"
              class="py-8 text-sm text-center text-n-slate-11"
            >
              {{ $t('CRM.DASHBOARD.EMPTY') }}
            </li>
          </ul>
        </article>
      </div></template
    >
  </section>
</template>
