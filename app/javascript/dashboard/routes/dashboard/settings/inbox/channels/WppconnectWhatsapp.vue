<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import crmAPI from 'dashboard/api/crm';
import { useStore } from 'dashboard/composables/store';
import sessionStorage from 'shared/helpers/sessionStorage';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const session = ref(null);
const error = ref('');
const isLoading = ref(false);
const replaceDialog = ref(null);
const selectedTeamId = ref('');
const inboxName = ref('');
const nameError = ref(false);
let poller;
let isCreatingInbox = false;
let createInbox;

const accountId = computed(() => route.params.accountId);
const teams = computed(() => store.getters['teams/getTeams']);
const teamOptions = computed(() => [
  {
    value: '',
    label: t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.NO_TEAM'),
  },
  ...teams.value.map(team => ({ value: team.id, label: team.name })),
]);
const wizardStorageKey = computed(
  () => `wppconnect-wizard-session-${accountId.value}`
);
const newSessionKey = () => `wizard-${Date.now().toString(36)}`;
const currentSessionKey = ref(
  sessionStorage.get(wizardStorageKey.value) || newSessionKey()
);
const persistSessionKey = () =>
  sessionStorage.set(wizardStorageKey.value, currentSessionKey.value);
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
      name: inboxName.value.trim(),
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
    sessionStorage.remove(wizardStorageKey.value);
  } catch (_) {
    isCreatingInbox = false;
    error.value = t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.ERROR');
  }
};
const createSession = async () => {
  persistSessionKey();
  await crmAPI.createWppconnectSession(accountId.value, {
    session_key: currentSessionKey.value,
  });
  await refresh();
  startPolling();
};
const connect = async () => {
  error.value = '';
  nameError.value = !inboxName.value.trim();
  if (nameError.value) return;
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
    currentSessionKey.value = newSessionKey();
    persistSessionKey();
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
onBeforeUnmount(() => {
  stopPolling();

  // Leaving the setup wizard before pairing used to leave a browser and a QR
  // poller running in WPPConnect. Only temporary, unpaired wizard sessions
  // are removed here; a connected inbox session is never touched.
  if (!isConnected.value && session.value?.id) {
    crmAPI
      .deleteWppconnectSession(accountId.value, { session_id: session.value.id })
      .catch(() => {});
  }
});
</script>

<template>
  <div class="max-w-2xl">
    <div
      class="p-6 border rounded-2xl border-n-weak bg-n-solid-1 flex flex-col gap-5"
    >
      <div class="flex items-start gap-3">
        <span
          class="flex items-center justify-center flex-shrink-0 size-10 rounded-xl bg-n-teal-3 text-n-teal-11"
        >
          <span class="i-ri-whatsapp-line size-5" />
        </span>
        <div class="min-w-0">
          <h2 class="text-base font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.TITLE') }}
          </h2>
          <p class="mt-1 text-sm leading-relaxed text-n-slate-11">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.DESCRIPTION') }}
          </p>
        </div>
      </div>

      <div class="px-4 py-3 text-sm rounded-xl bg-n-ruby-2 text-n-ruby-11">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.WARNING') }}
      </div>

      <form
        v-if="!isConnected"
        class="flex flex-col gap-5"
        @submit.prevent="connect"
      >
        <div>
          <label class="block mb-2 text-sm font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.NAME') }}
          </label>
          <input
            v-model="inboxName"
            type="text"
            maxlength="80"
            class="!mb-0 w-full"
            :class="{ '!outline-n-ruby-8': nameError }"
            :placeholder="
              $t(
                'INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.NAME_PLACEHOLDER'
              )
            "
            @input="nameError = false"
          />
          <p
            class="mt-2 text-sm"
            :class="nameError ? 'text-n-ruby-11' : 'text-n-slate-11'"
          >
            {{
              nameError
                ? $t(
                    'INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.NAME_REQUIRED'
                  )
                : $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.NAME_HELP')
            }}
          </p>
        </div>

        <div>
          <label class="block mb-2 text-sm font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.TEAM') }}
          </label>
          <SelectInput v-model="selectedTeamId" :options="teamOptions" />
          <p class="mt-2 text-sm text-n-slate-11">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.TEAM_HELP') }}
          </p>
        </div>

        <div
          class="flex items-start gap-2 px-4 py-3 text-sm rounded-xl bg-n-alpha-1 text-n-slate-11"
        >
          <span class="i-lucide-eye flex-shrink-0 mt-0.5 size-4" />
          {{
            $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.SUPERVISOR_NOTE')
          }}
        </div>

        <div>
          <Button
            :label="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.CONNECT')"
            :is-loading="isLoading"
            type="submit"
          />
        </div>
      </form>

      <div v-else>
        <Button
          color="ruby"
          variant="outline"
          :label="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.REPLACE')"
          :is-loading="isLoading"
          @click="replaceDialog?.open()"
        />
      </div>

      <p v-if="error" class="text-sm text-n-ruby-11">{{ error }}</p>

      <div
        v-if="session"
        class="flex flex-col items-center gap-3 p-5 text-center border rounded-xl border-n-weak bg-n-background"
      >
        <p class="text-sm text-n-slate-11">
          {{
            $t(
              'INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.STATUS_WITH_VALUE',
              { status: session.status }
            )
          }}
        </p>
        <img
          v-if="session.qr"
          :src="session.qr"
          class="p-3 bg-white rounded-xl size-56"
          :alt="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.QR_ALT')"
        />
        <p v-if="session.qr" class="max-w-xs text-sm text-n-slate-11">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.STEP_3') }}
        </p>
        <p v-if="session.phone" class="text-sm font-medium text-n-slate-12">
          {{
            $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.PHONE', {
              phone: `+${session.phone}`,
            })
          }}
        </p>
      </div>
    </div>

    <Dialog
      ref="replaceDialog"
      type="alert"
      :title="$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.REPLACE_TITLE')"
      :description="
        $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.REPLACE_DESCRIPTION')
      "
      :confirm-button-label="
        $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WPPCONNECT.REPLACE')
      "
      @confirm="replaceNumber"
    />
  </div>
</template>
