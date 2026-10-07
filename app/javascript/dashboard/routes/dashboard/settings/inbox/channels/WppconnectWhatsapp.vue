<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
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
const selectedTeamId = ref('');
let poller;
let isCreatingInbox = false;
let createInbox;

const accountId = computed(() => route.params.accountId);
const teams = computed(() => store.getters['teams/getTeams']);
const teamOptions = computed(() => [
  { value: '', label: t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.NO_TEAM') },
  ...teams.value.map(team => ({ value: team.id, label: team.name })),
]);
const currentSessionKey = ref(`wizard-${Date.now().toString(36)}`);
const isConnected = computed(() => session.value?.status === 'connected');
const stopPolling = () => clearInterval(poller);
const refresh = async () => {
  const { data } = await crmAPI.getWppconnectSession(accountId.value, {
    session_key: currentSessionKey.value,
  });
  session.value = data;
  if (isConnected.value) {
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
      `account-${accountId.value}-wppconnect-${currentSessionKey.value}`;
    const inbox = await store.dispatch('inboxes/createChannel', {
      name: 'WhatsApp WPPConnect',
      channel: {
        type: 'api',
        additional_attributes: {
          provider: 'wppconnect',
          session_id: activeSessionId,
          default_team_id: selectedTeamId.value || null,
        },
      },
    });
    await crmAPI.createWppconnectSession(accountId.value, {
      inbox_id: inbox.id,
      session_id: activeSessionId,
      team_id: selectedTeamId.value || null,
    });
    await router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: inbox.id },
    });
  } catch (_) {
    isCreatingInbox = false;
    error.value = t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.ERROR');
  }
};
const createSession = async () => {
  await crmAPI.createWppconnectSession(accountId.value, {
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
      await crmAPI.deleteWppconnectSession(accountId.value, {
        session_id: session.value.id,
      });
      session.value = null;
    }
    await createSession();
  } catch (_) {
    error.value = t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.ERROR');
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
      await crmAPI.deleteWppconnectSession(accountId.value, {
        session_id: session.value.id,
      });
    }
    session.value = null;
    currentSessionKey.value = `wizard-${Date.now().toString(36)}`;
    await createSession();
  } catch (_) {
    error.value = t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.ERROR');
  } finally {
    isLoading.value = false;
  }
};
onMounted(() => {
  store.dispatch('teams/get');
  refresh().catch(() => {});
});
onBeforeUnmount(stopPolling);
</script>

<template>
  <div class="max-w-xl">
    <h2 class="text-lg font-medium text-n-slate-12">
      {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.TITLE') }}
    </h2>
    <p class="mt-2 text-sm leading-relaxed text-n-slate-11">
      {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.DESCRIPTION') }}
    </p>
    <div class="p-4 mt-5 text-sm rounded-xl bg-n-ruby-2 text-n-ruby-11">
      {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.WARNING') }}
    </div>
    <div v-if="!isConnected" class="mt-5">
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.TEAM') }}
      </label>
      <SelectInput v-model="selectedTeamId" :options="teamOptions" />
      <p class="mt-2 text-sm text-n-slate-11">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.TEAM_HELP') }}
      </p>
    </div>
    <form v-if="!isConnected" class="mt-6" @submit.prevent="connect">
      <Button
        :label="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.CONNECT')"
        :is-loading="isLoading"
        type="submit"
      />
    </form>
    <Button
      v-else
      class="mt-6"
      color="ruby"
      variant="outline"
      :label="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.REPLACE')"
      :is-loading="isLoading"
      @click="replaceDialog?.open()"
    />
    <p v-if="error" class="mt-4 text-sm text-n-ruby-11">{{ error }}</p>
    <div v-if="session" class="mt-6">
      <p class="text-sm text-n-slate-11">
        {{
          $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.STATUS_WITH_VALUE', {
            status: session.status,
          })
        }}
      </p>
      <p v-if="session.phone" class="mt-2 text-sm text-n-slate-11">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.PHONE', { phone: `+${session.phone}` }) }}
      </p>
      <img
        v-if="session.qr"
        :src="session.qr"
        class="p-3 mt-4 bg-white rounded-xl"
        :alt="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.QR_ALT')"
      />
    </div>
    <Dialog
      ref="replaceDialog"
      type="alert"
      :title="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.REPLACE_TITLE')"
      :description="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.REPLACE_DESCRIPTION')"
      :confirm-button-label="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.REPLACE')"
      @confirm="replaceNumber"
    />
  </div>
</template>
