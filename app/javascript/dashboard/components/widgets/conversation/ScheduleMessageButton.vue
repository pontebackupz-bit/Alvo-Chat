<script setup>
// Writes a message now and has the platform send it at a chosen time, as
// the person who scheduled it. Also lists and cancels this conversation's
// pending ones.
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import crmAPI from 'dashboard/api/crm';

const props = defineProps({
  chat: { type: Object, required: true },
});

const { t, locale } = useI18n();
const accountId = useMapGetter('getCurrentAccountId');
const show = ref(false);
const content = ref('');
const when = ref('');
const pending = ref([]);
const isSaving = ref(false);

const pad = value => String(value).padStart(2, '0');
// Value for <input type="datetime-local"> in the browser's time zone.
const toLocalInput = date =>
  `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;

const at = (days, hour) => {
  const date = new Date();
  date.setDate(date.getDate() + days);
  date.setHours(hour, 0, 0, 0);
  return date;
};

const shortcuts = computed(() => {
  const inOneHour = new Date(Date.now() + 60 * 60 * 1000);
  const nextMonday = (8 - new Date().getDay()) % 7 || 7;
  return [
    { key: 'HOUR', date: inOneHour },
    { key: 'TOMORROW', date: at(1, 9) },
    { key: 'MONDAY', date: at(nextMonday, 9) },
  ];
});

const minimum = computed(() => toLocalInput(new Date(Date.now() + 60 * 1000)));

const formatDate = value =>
  new Intl.DateTimeFormat(locale.value.replace('_', '-'), {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(value));

const fetchPending = async () => {
  try {
    const { data } = await crmAPI.getScheduledMessages(accountId.value, {
      conversation_id: props.chat.id,
      status: 'pending',
    });
    pending.value = data.scheduled_messages || [];
  } catch (_) {
    pending.value = [];
  }
};

const open = () => {
  content.value = '';
  when.value = toLocalInput(shortcuts.value[0].date);
  show.value = true;
  fetchPending();
};

const save = async () => {
  if (!content.value.trim() || !when.value) return;
  isSaving.value = true;
  try {
    await crmAPI.createScheduledMessage(accountId.value, {
      conversation_id: props.chat.id,
      content: content.value.trim(),
      scheduled_at: new Date(when.value).toISOString(),
    });
    useAlert(
      t('ATTENDANCE.SCHEDULE.SAVED', {
        date: formatDate(new Date(when.value)),
      }),
      { status: 'success' }
    );
    show.value = false;
  } catch (error) {
    useAlert(error.response?.data?.error || t('ATTENDANCE.SCHEDULE.ERROR'), {
      status: 'error',
    });
  } finally {
    isSaving.value = false;
  }
};

const cancel = async item => {
  try {
    await crmAPI.cancelScheduledMessage(accountId.value, item.id);
    pending.value = pending.value.filter(row => row.id !== item.id);
    useAlert(t('ATTENDANCE.SCHEDULE.CANCELLED'), { status: 'success' });
  } catch (error) {
    useAlert(error.response?.data?.error || t('ATTENDANCE.SCHEDULE.ERROR'), {
      status: 'error',
    });
  }
};
</script>

<template>
  <Button
    v-tooltip.bottom="$t('ATTENDANCE.SCHEDULE.TOOLTIP')"
    icon="i-lucide-calendar-clock"
    size="sm"
    variant="ghost"
    color="slate"
    @click="open"
  />
  <woot-modal v-model:show="show" :on-close="() => (show = false)">
    <form class="crm-modal-form" @submit.prevent="save">
      <woot-modal-header
        :header-title="$t('ATTENDANCE.SCHEDULE.TITLE')"
        :header-content="$t('ATTENDANCE.SCHEDULE.DESCRIPTION')"
      />
      <label>
        {{ $t('ATTENDANCE.SCHEDULE.MESSAGE') }}
        <textarea v-model="content" rows="4" required maxlength="4096" />
      </label>
      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('ATTENDANCE.SCHEDULE.WHEN') }}
        </span>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="shortcut in shortcuts"
            :key="shortcut.key"
            type="button"
            class="px-3 py-1.5 text-xs font-medium rounded-md border transition-colors"
            :class="
              when === toLocalInput(shortcut.date)
                ? 'border-n-brand bg-n-brand/10 text-n-blue-11'
                : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-2'
            "
            @click="when = toLocalInput(shortcut.date)"
          >
            {{ $t(`ATTENDANCE.SCHEDULE.SHORTCUTS.${shortcut.key}`) }}
          </button>
        </div>
        <input
          v-model="when"
          type="datetime-local"
          required
          :min="minimum"
          class="!mb-0 !h-10 text-sm"
        />
      </div>

      <div v-if="pending.length" class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('ATTENDANCE.SCHEDULE.PENDING') }}
        </span>
        <div
          v-for="item in pending"
          :key="item.id"
          class="flex items-start justify-between gap-3 p-3 text-sm border rounded-lg border-n-weak"
        >
          <span class="min-w-0">
            <span class="block text-xs text-n-slate-11">
              {{ formatDate(item.scheduled_at) }} · {{ item.author }}
            </span>
            <span class="block truncate text-n-slate-12">
              {{ item.content }}
            </span>
          </span>
          <Button
            v-if="item.can_cancel"
            type="button"
            size="xs"
            variant="ghost"
            color="ruby"
            icon="i-lucide-x"
            :label="$t('ATTENDANCE.SCHEDULE.CANCEL')"
            @click="cancel(item)"
          />
        </div>
      </div>

      <div class="crm-form-actions">
        <Button
          type="button"
          variant="faded"
          color="slate"
          :label="$t('CRM.COMMON.CANCEL')"
          @click="show = false"
        />
        <Button
          type="submit"
          icon="i-lucide-calendar-clock"
          :is-loading="isSaving"
          :disabled="!content.trim() || !when"
          :label="$t('ATTENDANCE.SCHEDULE.SUBMIT')"
        />
      </div>
    </form>
  </woot-modal>
</template>
