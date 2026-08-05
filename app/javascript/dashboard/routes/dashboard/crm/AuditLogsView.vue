<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { BaseTable } from 'dashboard/components-next/table';
import crmAPI from 'dashboard/api/crm';
import CrmPageHeader from './CrmPageHeader.vue';

const { t } = useI18n();
const route = useRoute();
const accountId = computed(() => route.params.accountId);
const isLoading = ref(false);
const logs = ref([]);
const headers = computed(() => [
  t('CRM.AUDIT.EVENT'),
  t('CRM.AUDIT.ACTOR'),
  t('CRM.AUDIT.DATE'),
]);
const fetchLogs = async () => {
  isLoading.value = true;
  try {
    const { data } = await crmAPI.getAuditLogs(accountId.value);
    logs.value = Array.isArray(data) ? data : data.audit_logs || [];
  } catch (error) {
    useAlert(t('CRM.AUDIT.FETCH_ERROR'));
  } finally {
    isLoading.value = false;
  }
};
const formatDate = value =>
  new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
onMounted(fetchLogs);
</script>

<template>
  <section>
    <CrmPageHeader
      :title="$t('CRM.AUDIT.TITLE')"
      :description="$t('CRM.AUDIT.DESCRIPTION')"
    />
    <woot-loading-state v-if="isLoading" :message="$t('CRM.COMMON.LOADING')" />
    <BaseTable
      v-else
      :headers="headers"
      :items="logs"
      :no-data-message="$t('CRM.AUDIT.EMPTY')"
      ><template #row="{ items }"
        ><tr v-for="log in items" :key="log.id">
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-12">
            {{ log.event_type }}
          </td>
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
            {{ log.actor_id ? `#${log.actor_id}` : '—' }}
          </td>
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
            {{ formatDate(log.created_at) }}
          </td>
        </tr></template
      ></BaseTable
    >
  </section>
</template>
