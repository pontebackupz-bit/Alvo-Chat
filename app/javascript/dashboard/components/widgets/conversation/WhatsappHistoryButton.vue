<script setup>
// Loads every message WhatsApp has for this contact (or group) into the open
// conversation, for numbers connected by QR code (WPPConnect).
import { computed, onBeforeUnmount, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import crmAPI from 'dashboard/api/crm';
import MessageApi from 'dashboard/api/inbox/message';
import types from 'dashboard/store/mutation-types';

const props = defineProps({
  inbox: { type: Object, default: () => ({}) },
  chat: { type: Object, required: true },
});

const POLL_MS = 3000;
const POLL_LIMIT = 100;

const store = useStore();
const { t } = useI18n();
const isLoading = ref(false);
let timer = null;

const accountId = computed(() => store.getters.getCurrentAccountId);
const isAvailable = computed(
  () => props.inbox?.additional_attributes?.provider === 'wppconnect'
);

// The newest page again, with older pages loadable by scrolling up.
const refreshMessages = async () => {
  const { data } = await MessageApi.getPreviousMessages({
    conversationId: props.chat.id,
  });
  store.commit(types.SET_MISSING_MESSAGES, {
    id: props.chat.id,
    data: data.payload,
  });
  store.commit(types.CLEAR_ALL_MESSAGES_LOADED, props.chat.id);
};

const finish = async history => {
  isLoading.value = false;
  if (history.status === 'failed') {
    useAlert(history.error || t('CONVERSATION.WHATSAPP_HISTORY.ERROR'), {
      status: 'error',
    });
    return;
  }
  await refreshMessages();
  useAlert(
    history.messages
      ? t('CONVERSATION.WHATSAPP_HISTORY.DONE', { count: history.messages })
      : t('CONVERSATION.WHATSAPP_HISTORY.UP_TO_DATE'),
    { status: 'success' }
  );
};

const poll = async (attempt = 0) => {
  try {
    const { data } = await crmAPI.getConversationHistory(
      accountId.value,
      props.chat.id
    );
    if (['completed', 'failed'].includes(data.status)) {
      await finish(data);
      return;
    }
  } catch (_) {
    // The next check may succeed.
  }
  if (attempt >= POLL_LIMIT) {
    isLoading.value = false;
    return;
  }
  timer = setTimeout(() => poll(attempt + 1), POLL_MS);
};

const loadHistory = async () => {
  isLoading.value = true;
  try {
    await crmAPI.importConversationHistory(accountId.value, props.chat.id);
    poll();
  } catch (error) {
    isLoading.value = false;
    useAlert(
      error.response?.data?.error || t('CONVERSATION.WHATSAPP_HISTORY.ERROR'),
      { status: 'error' }
    );
  }
};

onBeforeUnmount(() => clearTimeout(timer));
</script>

<template>
  <Button
    v-if="isAvailable"
    v-tooltip.bottom="$t('CONVERSATION.WHATSAPP_HISTORY.TOOLTIP')"
    icon="i-lucide-history"
    size="sm"
    variant="ghost"
    color="slate"
    :is-loading="isLoading"
    :label="
      isLoading
        ? $t('CONVERSATION.WHATSAPP_HISTORY.LOADING')
        : $t('CONVERSATION.WHATSAPP_HISTORY.BUTTON')
    "
    @click="loadHistory"
  />
</template>
