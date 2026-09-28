<script setup>
/* global axios */
import {
  computed,
  onActivated,
  onBeforeUnmount,
  onDeactivated,
  ref,
  watch,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { picoSearch } from '@scmmishra/pico-search';
import Avatar from 'next/avatar/Avatar.vue';
import { useAdmin } from 'dashboard/composables/useAdmin';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import {
  useMapGetter,
  useStoreGetters,
  useStore,
} from 'dashboard/composables/store';
import ChannelName from './components/ChannelName.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();
const { isAdmin } = useAdmin();

const showDeletePopup = ref(false);
const selectedInbox = ref({});
const searchQuery = ref('');
const selectedWhatsAppInbox = ref(null);
const baileysSession = ref(null);
const isLoadingBaileysSession = ref(false);
const baileysSessions = ref({});
let baileysStatusPolling;

const inboxes = useMapGetter('inboxes/getInboxes');

const inboxesList = computed(() => {
  return inboxes.value?.slice().sort((a, b) => a.name.localeCompare(b.name));
});

const filteredInboxesList = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return inboxesList.value;
  return picoSearch(inboxesList.value, query, ['name', 'channel_type']);
});

const uiFlags = computed(() => getters['inboxes/getUIFlags'].value);
const accountId = computed(() => store.getters.getCurrentAccountId);
const isBaileysInbox = inbox =>
  String(inbox.name || '').toLocaleLowerCase().includes('whatsapp');
const baileysSessionUrl = () =>
  `/api/v1/accounts/${accountId.value}/crm/baileys_session`;
const baileysSessionParams = inboxId => ({ params: { inbox_id: inboxId } });
const baileysStatus = inbox => baileysSessions.value[inbox.id]?.status || 'not_started';
const supportsBrowserNotifications =
  typeof window !== 'undefined' && 'Notification' in window;
const notificationsEnabled = computed(
  () => supportsBrowserNotifications && window.Notification.permission === 'granted'
);
const baileysStatusLabel = inbox => {
  const labels = {
    connected: 'Ativo',
    connecting: 'Conectando',
    reconnecting: 'Reconectando',
    qr_available: 'Aguardando leitura do QR',
    not_started: 'Desconectado',
  };

  return labels[baileysStatus(inbox)] || 'Desconectado';
};
const baileysStatusClass = inbox => {
  const status = baileysStatus(inbox);
  if (status === 'connected') return 'bg-n-teal-9';
  if (['connecting', 'reconnecting', 'qr_available'].includes(status)) return 'bg-n-amber-9';

  return 'bg-n-ruby-9';
};

const fetchBaileysSession = async inbox => {
  const previousStatus = baileysStatus(inbox);
  try {
    const response = await axios.get(
      baileysSessionUrl(),
      baileysSessionParams(inbox.id)
    );
    baileysSessions.value = { ...baileysSessions.value, [inbox.id]: response.data };
    notifyDisconnectedInbox(inbox, previousStatus, response.data.status);
  } catch (error) {
    baileysSessions.value = {
      ...baileysSessions.value,
      [inbox.id]: { status: 'not_started' },
    };
  }
};

const notifyDisconnectedInbox = (inbox, previousStatus, currentStatus) => {
  if (previousStatus !== 'connected' || currentStatus === 'connected') return;

  const message = `${inbox.name} foi desconectado. Renove o QR code para voltar a atender.`;
  useAlert(message);
  if (notificationsEnabled.value) {
    new window.Notification('WhatsApp desconectado', { body: message });
  }
};

const enableBrowserNotifications = async () => {
  if (!supportsBrowserNotifications) {
    useAlert('Este navegador não oferece suporte a notificações.');
    return;
  }

  const permission = await window.Notification.requestPermission();
  if (permission === 'granted') {
    useAlert('Notificações de conexão do WhatsApp ativadas.');
  }
};

const refreshBaileysStatuses = () => {
  (inboxes.value || []).filter(isBaileysInbox).forEach(fetchBaileysSession);
};

watch(
  inboxes,
  currentInboxes => {
    (currentInboxes || [])
      .filter(isBaileysInbox)
      .forEach(inbox => fetchBaileysSession(inbox));
  },
  { immediate: true }
);

const clearBaileysStatusPolling = () => {
  if (baileysStatusPolling) window.clearInterval(baileysStatusPolling);
  baileysStatusPolling = null;
};

onActivated(() => {
  store.dispatch('inboxes/get');
  refreshBaileysStatuses();
  clearBaileysStatusPolling();
  baileysStatusPolling = window.setInterval(refreshBaileysStatuses, 30000);
});

onDeactivated(clearBaileysStatusPolling);
onBeforeUnmount(clearBaileysStatusPolling);

const loadBaileysSession = async ({ create = false } = {}) => {
  if (!selectedWhatsAppInbox.value) return;

  isLoadingBaileysSession.value = true;
  try {
    const response = create
      ? await axios.post(
          baileysSessionUrl(),
          null,
          baileysSessionParams(selectedWhatsAppInbox.value.id)
        )
      : await axios.get(
          baileysSessionUrl(),
          baileysSessionParams(selectedWhatsAppInbox.value.id)
        );
    baileysSession.value = response.data;
    baileysSessions.value = {
      ...baileysSessions.value,
      [selectedWhatsAppInbox.value.id]: response.data,
    };
  } catch (error) {
    useAlert('Não foi possível gerar o QR code do WhatsApp.');
  } finally {
    isLoadingBaileysSession.value = false;
  }
};

const refreshWhatsAppQr = async inbox => {
  selectedWhatsAppInbox.value = inbox;
  baileysSession.value = null;
  isLoadingBaileysSession.value = true;

  try {
    const response = await axios.post(
      `${baileysSessionUrl()}/refresh`,
      null,
      baileysSessionParams(inbox.id)
    );
    baileysSession.value = response.data;
    baileysSessions.value = { ...baileysSessions.value, [inbox.id]: response.data };
  } catch (error) {
    useAlert('Não foi possível renovar o QR code do WhatsApp.');
  } finally {
    isLoadingBaileysSession.value = false;
  }
};

const closeWhatsAppConnection = () => {
  selectedWhatsAppInbox.value = null;
  baileysSession.value = null;
};

const deleteConfirmText = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.YES')} ${selectedInbox.value.name}`
);

const deleteRejectText = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.NO')} ${selectedInbox.value.name}`
);

const confirmDeleteMessage = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.MESSAGE')} ${selectedInbox.value.name}?`
);
const confirmPlaceHolderText = computed(
  () =>
    `${t('INBOX_MGMT.DELETE.CONFIRM.PLACE_HOLDER', {
      inboxName: selectedInbox.value.name,
    })}`
);

const deleteInbox = async ({ id }) => {
  try {
    await store.dispatch('inboxes/delete', id);
    useAlert(t('INBOX_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('INBOX_MGMT.DELETE.API.ERROR_MESSAGE'));
  }
};
const closeDelete = () => {
  showDeletePopup.value = false;
  selectedInbox.value = {};
};

const confirmDeletion = () => {
  deleteInbox(selectedInbox.value);
  closeDelete();
};
const openDelete = inbox => {
  showDeletePopup.value = true;
  selectedInbox.value = inbox;
};
</script>

<template>
  <SettingsLayout
    :no-records-found="!inboxesList.length"
    :no-records-message="$t('INBOX_MGMT.LIST.404')"
    :is-loading="uiFlags.isFetching"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('INBOX_MGMT.HEADER')"
        :description="$t('INBOX_MGMT.DESCRIPTION')"
        :link-text="$t('INBOX_MGMT.LEARN_MORE')"
        :search-placeholder="$t('INBOX_MGMT.SEARCH_PLACEHOLDER')"
        feature-name="inboxes"
      >
        <template v-if="inboxesList?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('INBOX_MGMT.COUNT', { n: inboxesList.length }) }}
          </span>
        </template>
        <template #actions>
          <Button
            v-if="supportsBrowserNotifications && !notificationsEnabled"
            label="Ativar notificações"
            icon="i-lucide-bell-ring"
            slate
            size="sm"
            @click="enableBrowserNotifications"
          />
          <router-link v-if="isAdmin" :to="{ name: 'settings_inbox_new' }">
            <Button :label="$t('SETTINGS.INBOXES.NEW_INBOX')" size="sm" />
          </router-link>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <span
        v-if="!filteredInboxesList.length && searchQuery"
        class="flex-1 flex items-center justify-center py-20 text-center text-body-main !text-base text-n-slate-11"
      >
        {{ $t('INBOX_MGMT.NO_RESULTS') }}
      </span>
      <div v-else class="divide-y divide-n-weak border-t border-n-weak">
        <div
          v-for="inbox in filteredInboxesList"
          :key="inbox.id"
          class="flex justify-between flex-row items-start gap-4 py-4"
        >
          <div class="flex items-center gap-4">
            <div
              v-if="inbox.avatar_url"
              class="bg-n-alpha-3 rounded-xl size-10 ring ring-n-solid-1 border border-n-strong shadow-sm grid place-items-center"
            >
              <Avatar
                :src="inbox.avatar_url"
                :name="inbox.name"
                :size="24"
                rounded-full
              />
            </div>
            <div
              v-else
              class="size-10 justify-center bg-n-alpha-3 rounded-xl ring ring-n-solid-1 border border-n-strong shadow-sm grid place-items-center"
            >
              <ChannelIcon class="size-6 text-n-slate-10" :inbox="inbox" />
            </div>
            <div class="flex flex-col items-start gap-1">
              <span class="block text-heading-3 text-n-slate-12 capitalize">
                {{ inbox.name }}
              </span>
              <ChannelName
                :channel-type="inbox.channel_type"
                :medium="inbox.medium"
                :voice-enabled="inbox.voice_enabled"
                class="text-body-main text-n-slate-11"
              />
              <span
                v-if="isBaileysInbox(inbox)"
                class="flex items-center gap-1.5 text-xs font-medium text-n-slate-11"
              >
                <span class="size-2 rounded-full" :class="baileysStatusClass(inbox)" />
                {{ baileysStatusLabel(inbox) }}
              </span>
            </div>
          </div>
          <div class="flex gap-3 justify-end">
            <Button
              v-if="isAdmin && isBaileysInbox(inbox)"
              label="Renovar QR"
              icon="i-lucide-refresh-cw"
              slate
              sm
              @click="refreshWhatsAppQr(inbox)"
            />
            <router-link
              :to="{
                name: 'settings_inbox_show',
                params: { inboxId: inbox.id },
              }"
            >
              <Button
                v-if="isAdmin"
                v-tooltip.top="$t('INBOX_MGMT.SETTINGS')"
                icon="i-woot-settings"
                slate
                sm
              />
            </router-link>
            <Button
              v-if="isAdmin"
              v-tooltip.top="$t('INBOX_MGMT.DELETE.BUTTON_TEXT')"
              icon="i-woot-bin"
              slate
              sm
              class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
              @click="openDelete(inbox)"
            />
          </div>
        </div>
      </div>
    </template>

    <Teleport to="body">
      <div
        v-if="selectedWhatsAppInbox"
        class="fixed inset-0 z-50 flex items-center justify-center bg-n-slate-12/70 p-4"
        @click.self="closeWhatsAppConnection"
      >
        <div class="w-full max-w-md rounded-2xl bg-n-solid-1 p-6 shadow-xl">
          <div class="flex items-start justify-between gap-4">
            <div>
              <p class="text-heading-3 text-n-slate-12">Conectar WhatsApp</p>
              <p class="mt-1 text-sm text-n-slate-11">{{ selectedWhatsAppInbox.name }}</p>
            </div>
            <Button icon="i-lucide-x" slate sm @click="closeWhatsAppConnection" />
          </div>
          <div class="mt-6 flex min-h-72 items-center justify-center rounded-xl bg-n-alpha-2 p-4">
            <img
              v-if="baileysSession?.qr"
              :src="baileysSession.qr"
              alt="QR code para conectar o WhatsApp"
              class="size-72 max-w-full rounded-lg bg-white p-2"
            />
            <div v-else class="text-center text-sm text-n-slate-11">
              <span v-if="isLoadingBaileysSession">Gerando QR code...</span>
              <span v-else-if="baileysSession?.status === 'connected'">WhatsApp conectado.</span>
              <span v-else>O QR code ainda não está disponível.</span>
            </div>
          </div>
          <p class="mt-5 text-sm leading-6 text-n-slate-11">
            No WhatsApp do celular: Configurações → Aparelhos conectados → Conectar aparelho.
          </p>
          <div class="mt-6 flex justify-end gap-3">
            <Button
              label="Atualizar status"
              slate
              sm
              :is-loading="isLoadingBaileysSession"
              @click="loadBaileysSession"
            />
            <Button label="Fechar" sm @click="closeWhatsAppConnection" />
          </div>
        </div>
      </div>
    </Teleport>

    <woot-confirm-delete-modal
      v-if="showDeletePopup"
      v-model:show="showDeletePopup"
      :title="$t('INBOX_MGMT.DELETE.CONFIRM.TITLE')"
      :message="confirmDeleteMessage"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
      :confirm-value="selectedInbox.name"
      :confirm-place-holder-text="confirmPlaceHolderText"
      @on-confirm="confirmDeletion"
      @on-close="closeDelete"
    />
  </SettingsLayout>
</template>
