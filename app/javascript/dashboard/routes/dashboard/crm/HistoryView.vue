<script setup>
// "Histórico de chats": finished conversations the user can see, newest
// first, with search and filters. A row opens the conversation.
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import crmAPI from 'dashboard/api/crm';
import CrmPageHeader from './CrmPageHeader.vue';

const { t, locale } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const agents = useMapGetter('agents/getAgents');
const accountId = computed(() => route.params.accountId);

const rows = ref([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(25);
const isLoading = ref(false);
const filters = ref({ search: '', assignee_id: '', since: '', until: '' });
let searchTimer = null;

const pages = computed(() =>
  Math.max(1, Math.ceil(total.value / pageSize.value))
);

const fetchHistory = async () => {
  isLoading.value = true;
  try {
    const params = Object.fromEntries(
      Object.entries({ ...filters.value, page: page.value }).filter(
        ([, value]) => value !== '' && value !== null
      )
    );
    const { data } = await crmAPI.getChatHistory(accountId.value, params);
    rows.value = data.conversations || [];
    total.value = data.total || 0;
    pageSize.value = data.page_size || 25;
  } catch (_) {
    useAlert(t('ATTENDANCE.HISTORY.FETCH_ERROR'), { status: 'error' });
  } finally {
    isLoading.value = false;
  }
};

const applyFilters = () => {
  page.value = 1;
  fetchHistory();
};

watch(
  () => filters.value.search,
  () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(applyFilters, 400);
  }
);
watch(
  () => [filters.value.assignee_id, filters.value.since, filters.value.until],
  applyFilters
);

const goToPage = value => {
  page.value = Math.min(Math.max(1, value), pages.value);
  fetchHistory();
};

const openConversation = row =>
  router.push({
    name: 'inbox_conversation',
    params: { accountId: accountId.value, conversation_id: row.id },
  });

const formatDate = value =>
  value
    ? new Intl.DateTimeFormat(locale.value.replace('_', '-'), {
        dateStyle: 'short',
        timeStyle: 'short',
      }).format(new Date(value))
    : '—';

onMounted(() => {
  store.dispatch('agents/get');
  fetchHistory();
});
</script>

<template>
  <section>
    <CrmPageHeader
      :title="$t('ATTENDANCE.HISTORY.TITLE')"
      :description="$t('ATTENDANCE.HISTORY.DESCRIPTION')"
    />

    <div class="flex flex-wrap items-center gap-3 mt-6 alvo-rise">
      <div class="relative flex-1 min-w-64">
        <span
          class="absolute -translate-y-1/2 pointer-events-none i-lucide-search size-4 left-3 top-1/2 text-n-slate-10"
        />
        <input
          v-model.trim="filters.search"
          type="search"
          class="!mb-0 !h-9 !pl-9 text-sm rounded-lg"
          :placeholder="$t('ATTENDANCE.SEARCH_PLACEHOLDER')"
        />
      </div>
      <select
        v-model="filters.assignee_id"
        class="!mb-0 !w-auto min-w-48 !h-9 text-sm"
      >
        <option value="">{{ $t('ATTENDANCE.HISTORY.ANY_AGENT') }}</option>
        <option v-for="agent in agents" :key="agent.id" :value="agent.id">
          {{ agent.name }}
        </option>
      </select>
      <label class="flex items-center gap-2 text-sm text-n-slate-11">
        {{ $t('ATTENDANCE.HISTORY.FROM') }}
        <input
          v-model="filters.since"
          type="date"
          class="!mb-0 !w-auto !h-9 text-sm"
        />
      </label>
      <label class="flex items-center gap-2 text-sm text-n-slate-11">
        {{ $t('ATTENDANCE.HISTORY.TO') }}
        <input
          v-model="filters.until"
          type="date"
          class="!mb-0 !w-auto !h-9 text-sm"
        />
      </label>
    </div>

    <div class="mt-5 overflow-x-auto border rounded-xl border-n-weak alvo-rise">
      <table class="w-full text-sm">
        <thead class="bg-n-alpha-1 text-n-slate-11">
          <tr>
            <th class="px-4 py-3 font-medium text-left">
              {{ $t('ATTENDANCE.HISTORY.PROTOCOL') }}
            </th>
            <th class="px-4 py-3 font-medium text-left">
              {{ $t('ATTENDANCE.HISTORY.CONTACT') }}
            </th>
            <th class="px-4 py-3 font-medium text-left">
              {{ $t('ATTENDANCE.HISTORY.AGENT') }}
            </th>
            <th class="px-4 py-3 font-medium text-left">
              {{ $t('ATTENDANCE.HISTORY.TEAM') }}
            </th>
            <th class="px-4 py-3 font-medium text-left">
              {{ $t('ATTENDANCE.HISTORY.INBOX') }}
            </th>
            <th class="px-4 py-3 font-medium text-right">
              {{ $t('ATTENDANCE.HISTORY.FINISHED_AT') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-n-weak">
          <tr
            v-for="row in rows"
            :key="row.id"
            class="transition-colors cursor-pointer hover:bg-n-alpha-1"
            @click="openConversation(row)"
          >
            <td class="px-4 py-3 font-medium text-n-blue-11">
              {{ `#${row.id}` }}
            </td>
            <td class="px-4 py-3">
              <span class="flex items-center gap-2 text-n-slate-12">
                <span
                  v-if="row.group"
                  v-tooltip="$t('ATTENDANCE.HISTORY.GROUP')"
                  class="i-lucide-users-round size-4 text-n-slate-10"
                />
                {{ row.contact.name }}
              </span>
              <span class="block text-xs text-n-slate-11">
                {{ row.contact.phone }}
              </span>
            </td>
            <td class="px-4 py-3 text-n-slate-11">{{ row.assignee || '—' }}</td>
            <td class="px-4 py-3 text-n-slate-11">{{ row.team || '—' }}</td>
            <td class="px-4 py-3 text-n-slate-11">{{ row.inbox }}</td>
            <td class="px-4 py-3 text-right text-n-slate-11 whitespace-nowrap">
              {{ formatDate(row.last_activity_at) }}
            </td>
          </tr>
          <tr v-if="!rows.length">
            <td colspan="6" class="py-12 text-center text-n-slate-11">
              <span v-if="isLoading">{{ $t('CRM.COMMON.LOADING') }}</span>
              <span v-else>{{ $t('ATTENDANCE.HISTORY.EMPTY') }}</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div
      v-if="total > pageSize"
      class="flex items-center justify-between mt-4 text-sm text-n-slate-11"
    >
      <span>
        {{ $t('ATTENDANCE.HISTORY.PAGE', { page, pages, total }) }}
      </span>
      <div class="flex gap-2">
        <Button
          size="sm"
          variant="faded"
          color="slate"
          icon="i-lucide-chevron-left"
          :disabled="page <= 1"
          @click="goToPage(page - 1)"
        />
        <Button
          size="sm"
          variant="faded"
          color="slate"
          icon="i-lucide-chevron-right"
          :disabled="page >= pages"
          @click="goToPage(page + 1)"
        />
      </div>
    </div>
  </section>
</template>
