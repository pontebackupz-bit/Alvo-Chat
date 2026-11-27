<script setup>
// "Mensagens agendadas": what the team scheduled in the conversations the
// user can see, by status. Messages are scheduled from a conversation.
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import crmAPI from 'dashboard/api/crm';
import CrmPageHeader from './CrmPageHeader.vue';

const STATUSES = ['pending', 'sent', 'failed', 'cancelled'];
const STATUS_STYLE = {
  pending: 'bg-n-amber-3 text-n-amber-11',
  sent: 'bg-n-teal-3 text-n-teal-11',
  failed: 'bg-n-ruby-3 text-n-ruby-11',
  cancelled: 'bg-n-alpha-2 text-n-slate-11',
};

const { t, locale } = useI18n();
const route = useRoute();
const router = useRouter();
const accountId = computed(() => route.params.accountId);
const status = ref('pending');
const items = ref([]);
const isLoading = ref(false);

const fetchItems = async () => {
  isLoading.value = true;
  try {
    const { data } = await crmAPI.getScheduledMessages(accountId.value, {
      status: status.value,
    });
    items.value = data.scheduled_messages || [];
  } catch (_) {
    useAlert(t('ATTENDANCE.SCHEDULED.FETCH_ERROR'), { status: 'error' });
  } finally {
    isLoading.value = false;
  }
};

const selectStatus = value => {
  status.value = value;
  fetchItems();
};

const cancel = async item => {
  try {
    await crmAPI.cancelScheduledMessage(accountId.value, item.id);
    useAlert(t('ATTENDANCE.SCHEDULE.CANCELLED'), { status: 'success' });
    fetchItems();
  } catch (error) {
    useAlert(error.response?.data?.error || t('ATTENDANCE.SCHEDULE.ERROR'), {
      status: 'error',
    });
  }
};

const openConversation = item =>
  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: accountId.value,
      conversation_id: item.conversation.id,
    },
  });

const formatDate = value =>
  value
    ? new Intl.DateTimeFormat(locale.value.replace('_', '-'), {
        dateStyle: 'short',
        timeStyle: 'short',
      }).format(new Date(value))
    : '—';

onMounted(fetchItems);
</script>

<template>
  <section>
    <CrmPageHeader
      :title="$t('ATTENDANCE.SCHEDULED.TITLE')"
      :description="$t('ATTENDANCE.SCHEDULED.DESCRIPTION')"
    />

    <div class="flex gap-1 mt-6 alvo-rise">
      <button
        v-for="item in STATUSES"
        :key="item"
        type="button"
        class="px-3 py-1.5 text-sm font-medium rounded-md transition-colors"
        :class="
          status === item
            ? 'bg-n-brand/15 text-n-blue-11'
            : 'text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
        "
        @click="selectStatus(item)"
      >
        {{ $t(`ATTENDANCE.SCHEDULED.STATUS.${item}`) }}
      </button>
    </div>

    <div class="flex flex-col gap-3 mt-5">
      <article
        v-for="(item, index) in items"
        :key="item.id"
        class="flex items-start justify-between gap-4 p-4 border rounded-xl border-n-weak bg-n-solid-1 alvo-rise alvo-card"
        :style="{ '--alvo-delay': `${index * 40}ms` }"
      >
        <div class="min-w-0">
          <div
            class="flex flex-wrap items-center gap-2 text-xs text-n-slate-11"
          >
            <span
              class="px-2 py-0.5 font-medium rounded-full"
              :class="STATUS_STYLE[item.status]"
            >
              {{ $t(`ATTENDANCE.SCHEDULED.STATUS.${item.status}`) }}
            </span>
            <span class="flex items-center gap-1">
              <span class="i-lucide-calendar-clock size-3.5" />
              {{ formatDate(item.scheduled_at) }}
            </span>
            <span>
              {{ $t('ATTENDANCE.SCHEDULED.BY', { name: item.author }) }}
            </span>
          </div>
          <button
            type="button"
            class="mt-2 text-sm font-medium text-n-blue-11 hover:underline"
            @click="openConversation(item)"
          >
            {{ `#${item.conversation.id} · ${item.conversation.contact}` }}
          </button>
          <p class="mt-1 text-sm whitespace-pre-line text-n-slate-12">
            {{ item.content }}
          </p>
          <p v-if="item.error" class="mt-1 text-xs text-n-ruby-11">
            {{ item.error }}
          </p>
        </div>
        <Button
          v-if="item.can_cancel"
          size="sm"
          variant="faded"
          color="ruby"
          icon="i-lucide-x"
          :label="$t('ATTENDANCE.SCHEDULE.CANCEL')"
          @click="cancel(item)"
        />
      </article>

      <div
        v-if="!items.length"
        class="flex flex-col items-center gap-3 px-6 py-16 text-center border border-dashed rounded-xl border-n-weak"
      >
        <span class="i-lucide-calendar-clock size-8 text-n-slate-10" />
        <p class="text-sm text-n-slate-11">
          <span v-if="isLoading">{{ $t('CRM.COMMON.LOADING') }}</span>
          <span v-else>{{ $t('ATTENDANCE.SCHEDULED.EMPTY') }}</span>
        </p>
      </div>
    </div>
  </section>
</template>
