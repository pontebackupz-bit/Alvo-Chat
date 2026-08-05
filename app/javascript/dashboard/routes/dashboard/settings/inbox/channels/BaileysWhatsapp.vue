<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import crmAPI from 'dashboard/api/crm';
import { useStore } from 'dashboard/composables/store';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const session = ref(null);
const error = ref('');
const isLoading = ref(false);
let poller;
let isCreatingInbox = false;
let createInbox;

const accountId = computed(() => route.params.accountId);
const stopPolling = () => clearInterval(poller);
const refresh = async () => {
  const { data } = await crmAPI.getBaileysSession(accountId.value);
  session.value = data;
  if (session.value.status === 'connected') {
    stopPolling();
    await createInbox();
  }
};
createInbox = async () => {
  if (isCreatingInbox) return;

  isCreatingInbox = true;
  try {
    const inbox = await store.dispatch('inboxes/createChannel', {
      name: `WhatsApp ${session.value.phone || 'Baileys'}`,
      channel: {
        type: 'api',
        additional_attributes: {
          provider: 'baileys',
          session_id: `account-${accountId.value}`,
        },
      },
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
const connect = async () => {
  error.value = '';
  isLoading.value = true;
  try {
    await crmAPI.createBaileysSession(accountId.value);
    await refresh();
    stopPolling();
    poller = setInterval(() => refresh().catch(() => stopPolling()), 2000);
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
    <form class="mt-6" @submit.prevent="connect">
      <Button
        :label="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS.CONNECT')"
        :is-loading="isLoading"
        type="submit"
      />
    </form>
    <p v-if="error" class="mt-4 text-sm text-n-ruby-11">{{ error }}</p>
    <div v-if="session" class="mt-6">
      <p class="text-sm text-n-slate-11">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS.STATUS') }}:
        {{ session.status }}
      </p>
      <img
        v-if="session.qr"
        :src="session.qr"
        class="p-3 mt-4 bg-white rounded-xl"
        :alt="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.BAILEYS.QR_ALT')"
      />
    </div>
  </div>
</template>
