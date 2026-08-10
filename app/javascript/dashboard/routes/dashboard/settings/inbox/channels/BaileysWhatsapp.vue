<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import crmAPI from 'dashboard/api/crm';
import { useStore } from 'dashboard/composables/store';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const session = ref(null);
const error = ref('');
const isLoading = ref(false);
const replaceDialog = ref(null);
let poller;
let isCreatingInbox = false;
let createInbox;

const accountId = computed(() => route.params.accountId);
const currentSessionKey = ref(`wizard-${Date.now().toString(36)}`);
const isConnected = computed(() => session.value?.status === 'connected');
const stopPolling = () => clearInterval(poller);
const refresh = async () => {
  const { data } = await crmAPI.getBaileysSession(accountId.value, {
    session_key: currentSessionKey.value,
  });
  session.value = data;
  if (session.value?.status === 'connected') {
    stopPolling();
    await createInbox();
  }
};
const startPolling = () => {
  stopPolling();
  poller = setInterval(() => refresh().catch(() => stopPolling()), 2000);
};
createInbox = async () => {
  if (isCreatingInbox) return;

  isCreatingInbox = true;
  try {
    const activeSessionId =
      session.value?.id ||
      `account-${accountId.value}-session-${currentSessionKey.value}`;
    const inbox = await store.dispatch('inboxes/createChannel', {
      name: `WhatsApp ${session.value?.phone || 'Baileys'}`,
      channel: {
        type: 'api',
        additional_attributes: {
          provider: 'baileys',
          session_id: activeSessionId,
        },
      },
    });
    await crmAPI.createBaileysSession(accountId.value, {
      inbox_id: inbox.id,
      session_id: activeSessionId,
    });
    await router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: inbox.id },
    });
  } catch (_) {
    isCreatingInbox = false;
    error.value = t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS.ERROR');
  }
};
const createSession = async () => {
  await crmAPI.createBaileysSession(accountId.value, {
    session_key: currentSessionKey.value,
  });
  await refresh();
  startPolling();
};
const connect = async () => {
  error.value = '';
  isLoading.value = true;
  try {
    if (session.value && session.value.status !== 'not_started') {
      await crmAPI.deleteBaileysSession(accountId.value, {
        session_id: session.value.id,
      });
      session.value = null;
    }
    await createSession();
  } catch (_) {
    error.value = t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS.ERROR');
  } finally {
    isLoading.value = false;
  }
};
const replaceNumber = async () => {
  replaceDialog.value?.close();
  error.value = '';
  isLoading.value = true;
  stopPolling();
  try {
    if (session.value?.id) {
      await crmAPI.deleteBaileysSession(accountId.value, {
        session_id: session.value.id,
      });
    }
    session.value = null;
    currentSessionKey.value = `wizard-${Date.now().toString(36)}`;
    await createSession();
  } catch (_) {
    error.value = t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS.ERROR');
  } finally {
    isLoading.value = false;
  }
};
onMounted(() => refresh().catch(() => {}));
onBeforeUnmount(stopPolling);
</script>

<template>
  <div class="max-w-xl">
    <h2 class="text-lg font-medium text-n-slate-12">
      {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS.TITLE') }}
    </h2>
    <p class="mt-2 text-sm leading-relaxed text-n-slate-11">
      {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS.DESCRIPTION') }}
    </p>
    <div class="p-4 mt-5 text-sm rounded-xl bg-n-ruby-2 text-n-ruby-11">
      {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS.WARNING') }}
    </div>
    <form v-if="!isConnected" class="mt-6" @submit.prevent="connect">
      <Button
        :label="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS.CONNECT')"
        :is-loading="isLoading"
        type="submit"
      />
    </form>
    <Button
      v-else
      class="mt-6"
      color="ruby"
      variant="outline"
      :label="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS.REPLACE')"
      :is-loading="isLoading"
      @click="replaceDialog?.open()"
    />
    <p v-if="error" class="mt-4 text-sm text-n-ruby-11">{{ error }}</p>
    <div v-if="session" class="mt-6">
      <p class="text-sm text-n-slate-11">
        {{
          $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS.STATUS_WITH_VALUE', {
            status: session.status,
          })
        }}
      </p>
      <img
        v-if="session.qr"
        :src="session.qr"
        class="p-3 mt-4 bg-white rounded-xl"
        :alt="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS.QR_ALT')"
      />
    </div>
    <Dialog
      ref="replaceDialog"
      type="alert"
      :title="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS.REPLACE_TITLE')"
      :description="
        $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS.REPLACE_DESCRIPTION')
      "
      :confirm-button-label="
        $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS.REPLACE')
      "
      @confirm="replaceNumber"
    />
  </div>
</template>
