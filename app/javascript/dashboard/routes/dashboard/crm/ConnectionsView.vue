<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import crmAPI from 'dashboard/api/crm';
import CrmPageHeader from './CrmPageHeader.vue';
import ConnectNumberWizard from './ConnectNumberWizard.vue';

const { t, locale } = useI18n();
const store = useStore();
const teams = useMapGetter('teams/getTeams');
const agents = useMapGetter('agents/getAgents');
const { isAdmin } = useAdmin();
const route = useRoute();
const router = useRouter();
const accountId = computed(() => route.params.accountId);

const connections = ref([]);
const isLoading = ref(false);
const search = ref('');
const creator = ref('');
const statusFilter = ref('');

const STATUS = {
  connected: {
    dot: 'bg-n-teal-9',
    pill: 'bg-n-teal-3 text-n-teal-11',
  },
  needs_qr: {
    dot: 'bg-n-amber-9',
    pill: 'bg-n-amber-3 text-n-amber-11',
  },
  connecting: {
    dot: 'bg-n-blue-9',
    pill: 'bg-n-blue-3 text-n-blue-11',
  },
  disconnected: {
    dot: 'bg-n-ruby-9',
    pill: 'bg-n-ruby-3 text-n-ruby-11',
  },
  unreachable: {
    dot: 'bg-n-slate-9',
    pill: 'bg-n-alpha-2 text-n-slate-11',
  },
};
const BRIDGES = ['wppconnect', 'baileys'];

// While a history import runs, the list refreshes to show its progress.
let importTimer = null;
const importing = computed(() =>
  connections.value.some(
    item =>
      ['queued', 'running'].includes(item.history_import?.status) ||
      ['connecting', 'needs_qr'].includes(item.status)
  )
);
const scheduleImportRefresh = () => {
  clearTimeout(importTimer);
  // eslint-disable-next-line no-use-before-define
  if (importing.value) importTimer = setTimeout(fetchConnections, 5000);
};

const fetchConnections = async () => {
  isLoading.value = true;
  try {
    const { data } = await crmAPI.getConnections(accountId.value);
    connections.value = data.connections || [];
    scheduleImportRefresh();
  } catch (_) {
    useAlert(t('CRM.CONNECTIONS.FETCH_ERROR'), { status: 'error' });
  } finally {
    isLoading.value = false;
  }
};

// While WhatsApp waits for a scan, the QR code stays open and the status is
// checked every few seconds until the number connects.
const qrSession = ref(null);
const POLL_MS = 2000;
const POLL_LIMIT = 60;
let pollTimer = null;

const stopPolling = () => {
  clearTimeout(pollTimer);
  pollTimer = null;
};

const importHistory = async connection => {
  try {
    await crmAPI.importConnectionHistory(accountId.value, connection.id);
    useAlert(t('CRM.CONNECTIONS.HISTORY.STARTED', { name: connection.name }), {
      status: 'success',
    });
    fetchConnections();
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('CRM.CONNECTIONS.HISTORY.ERROR'),
      { status: 'error' }
    );
  }
};

const historyText = connection => {
  const history = connection.history_import;
  if (!history) return '';
  const counts = { chats: history.chats || 0, messages: history.messages || 0 };
  if (history.status === 'completed') {
    return t('CRM.CONNECTIONS.HISTORY.DONE', {
      ...counts,
      // eslint-disable-next-line no-use-before-define
      date: formatDate(history.finished_at),
    });
  }
  if (history.status === 'failed') return t('CRM.CONNECTIONS.HISTORY.FAILED');
  return t('CRM.CONNECTIONS.HISTORY.RUNNING', counts);
};

const closeQr = () => {
  stopPolling();
  qrSession.value = null;
  fetchConnections();
};

const pollSession = async (connection, attempt = 0) => {
  if (!qrSession.value || attempt > POLL_LIMIT) return;
  try {
    const { data } = await crmAPI.getConnection(accountId.value, connection.id);
    if (data.status === 'connected') {
      useAlert(t('CRM.CONNECTIONS.CONNECTED', { name: connection.name }), {
        status: 'success',
      });
      // A number connected for the first time brings its chats along.
      const importAfter = qrSession.value?.importAfter;
      closeQr();
      if (importAfter) importHistory(connection);
      return;
    }
    if (data.qr) {
      qrSession.value = { ...qrSession.value, qr: data.qr };
    } else if (data.status === 'disconnected') {
      // The unscanned code expired and WPPConnect closed the browser: start
      // the session again for a fresh code.
      const restart = await crmAPI.reconnectConnection(
        accountId.value,
        connection.id
      );
      if (restart.data.qr) {
        qrSession.value = { ...qrSession.value, qr: restart.data.qr };
      }
    }
  } catch (_) {
    // Keep showing the last QR code; the next check may succeed.
  }
  pollTimer = setTimeout(() => pollSession(connection, attempt + 1), POLL_MS);
};

// Opens the QR window at once and fills it as soon as WhatsApp has a code;
// the polling restarts a closed session, so nobody waits on the card.
const reconnect = async connection => {
  stopPolling();
  qrSession.value = { connection, qr: null };
  try {
    const request = ['needs_qr', 'connecting'].includes(connection.status)
      ? crmAPI.getConnection(accountId.value, connection.id)
      : crmAPI.reconnectConnection(accountId.value, connection.id);
    const { data } = await request;
    if (data.status === 'connected') {
      useAlert(t('CRM.CONNECTIONS.CONNECTED', { name: connection.name }), {
        status: 'success',
      });
      closeQr();
      return;
    }
    if (data.qr) qrSession.value = { ...qrSession.value, qr: data.qr };
    pollSession(connection);
  } catch (error) {
    closeQr();
    useAlert(
      error.response?.data?.error || t('CRM.CONNECTIONS.RECONNECT_ERROR'),
      { status: 'error' }
    );
  }
};

// `{ id?, name, team_id }` while the create or settings form is open; no id
// means a new number.
const form = ref(null);
const isSaving = ref(false);
const isDeleting = ref(false);

const showWizard = ref(false);

const addNumber = () => {
  showWizard.value = true;
};

// The new number is saved: show its QR code and import its chats once it
// connects.
const onNumberCreated = async data => {
  showWizard.value = false;
  await fetchConnections();
  const connection = connections.value.find(item => item.id === data.id) || {
    id: data.id,
    name: data.name,
  };
  qrSession.value = { connection, qr: data.qr || null, importAfter: true };
  pollSession(connection);
};

const openSettings = connection => {
  form.value = {
    id: connection.id,
    name: connection.name,
    team_id: connection.team?.id || '',
    owner_id: connection.owner?.id || '',
    canManage: connection.can_manage,
    hasConversations: Boolean(connection.last_activity_at),
  };
};

const closeForm = () => {
  form.value = null;
};

const advancedSettings = () =>
  router.push({
    name: 'settings_inbox_show',
    params: { accountId: accountId.value, inboxId: form.value.id },
  });

const saveForm = async () => {
  const { id, name, team_id: teamId, owner_id: ownerId } = form.value;
  if (!name.trim()) {
    useAlert(t('CRM.CONNECTIONS.NAME_REQUIRED'), { status: 'warning' });
    return;
  }
  isSaving.value = true;
  try {
    if (id) {
      await crmAPI.updateConnection(accountId.value, id, {
        name: name.trim(),
        team_id: teamId || null,
        owner_id: ownerId || null,
      });
      useAlert(t('CRM.CONNECTIONS.SAVED'), { status: 'success' });
      closeForm();
      fetchConnections();
      return;
    }
    const { data } = await crmAPI.createConnection(accountId.value, {
      name: name.trim(),
      team_id: teamId || null,
    });
    closeForm();
    await fetchConnections();
    const connection = connections.value.find(item => item.id === data.id) || {
      id: data.id,
      name: name.trim(),
    };
    // The QR code may take a few seconds to exist; polling picks it up.
    qrSession.value = { connection, qr: data.qr || null, importAfter: true };
    pollSession(connection);
  } catch (error) {
    useAlert(error.response?.data?.error || t('CRM.CONNECTIONS.SAVE_ERROR'), {
      status: 'error',
    });
  } finally {
    isSaving.value = false;
  }
};

const deleteConnection = async () => {
  isDeleting.value = true;
  try {
    await crmAPI.deleteConnection(accountId.value, form.value.id);
    useAlert(t('CRM.CONNECTIONS.DELETED'), { status: 'success' });
    closeForm();
    fetchConnections();
  } catch (error) {
    useAlert(error.response?.data?.error || t('CRM.CONNECTIONS.SAVE_ERROR'), {
      status: 'error',
    });
  } finally {
    isDeleting.value = false;
  }
};

const creators = computed(() => {
  const people = new Map();
  connections.value.forEach(connection => {
    if (connection.created_by) {
      people.set(connection.created_by.id, connection.created_by.name);
    }
  });
  return [...people].map(([id, name]) => ({ id, name }));
});

const filtered = computed(() => {
  const term = search.value.trim().toLowerCase();
  return connections.value.filter(connection => {
    const text = [connection.name, connection.phone, connection.team?.name]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();
    if (term && !text.includes(term)) return false;
    if (creator.value === 'unknown' && connection.created_by) return false;
    if (
      creator.value &&
      creator.value !== 'unknown' &&
      connection.created_by?.id !== Number(creator.value)
    ) {
      return false;
    }
    return !statusFilter.value || connection.status === statusFilter.value;
  });
});

const summary = computed(() => {
  const count = status =>
    connections.value.filter(item => item.status === status).length;
  return [
    {
      key: 'total',
      icon: 'i-lucide-smartphone',
      value: connections.value.length,
    },
    {
      key: 'connected',
      icon: 'i-lucide-wifi',
      value: count('connected'),
      tone: 'text-n-teal-11',
    },
    {
      key: 'disconnected',
      icon: 'i-lucide-wifi-off',
      value: count('disconnected') + count('unreachable'),
      tone: 'text-n-ruby-11',
    },
    {
      key: 'open',
      icon: 'i-lucide-messages-square',
      value: connections.value.reduce(
        (sum, item) => sum + item.open_conversations,
        0
      ),
    },
  ];
});

const formatPhone = phone => {
  const digits = String(phone || '').replace(/\D/g, '');
  const match = digits.match(/^55(\d{2})(\d{4,5})(\d{4})$/);
  if (match) return `+55 (${match[1]}) ${match[2]}-${match[3]}`;
  return digits ? `+${digits}` : t('CRM.CONNECTIONS.NO_PHONE');
};

const formatDate = value =>
  value
    ? new Intl.DateTimeFormat(locale.value.replace('_', '-'), {
        dateStyle: 'short',
        timeStyle: 'short',
      }).format(new Date(value))
    : '—';

const statusLabel = status => t(`CRM.CONNECTIONS.STATUS.${status}`);
const providerLabel = provider => t(`CRM.CONNECTIONS.PROVIDERS.${provider}`);
const canReconnect = connection =>
  BRIDGES.includes(connection.provider) && connection.status !== 'connected';

onMounted(() => {
  fetchConnections();
  store.dispatch('teams/get');
  store.dispatch('agents/get');
});
onBeforeUnmount(() => {
  stopPolling();
  clearTimeout(importTimer);
});
</script>

<template>
  <section>
    <CrmPageHeader
      :title="$t('CRM.CONNECTIONS.TITLE')"
      :description="$t('CRM.CONNECTIONS.DESCRIPTION')"
      :action-label="$t('CRM.CONNECTIONS.ADD')"
      action-icon="i-lucide-plus"
      @action="addNumber"
    >
      <template #actions>
        <Button
          icon="i-lucide-refresh-cw"
          size="sm"
          variant="faded"
          color="slate"
          :is-loading="isLoading"
          :label="$t('CRM.CONNECTIONS.REFRESH')"
          @click="fetchConnections"
        />
      </template>
    </CrmPageHeader>

    <div class="grid gap-3 mt-6 sm:grid-cols-2 xl:grid-cols-4">
      <article
        v-for="(card, index) in summary"
        :key="card.key"
        class="p-4 border rounded-xl border-n-weak bg-n-solid-1 alvo-rise alvo-card"
        :style="{ '--alvo-delay': `${index * 60}ms` }"
      >
        <div class="flex items-center gap-2 text-sm text-n-slate-11">
          <span class="size-4" :class="card.icon" />
          {{ $t(`CRM.CONNECTIONS.SUMMARY.${card.key}`) }}
        </div>
        <p
          class="mt-2 text-2xl font-semibold"
          :class="card.tone || 'text-n-slate-12'"
        >
          {{ card.value }}
        </p>
      </article>
    </div>

    <div class="flex flex-wrap items-center gap-3 mt-6">
      <div class="relative flex-1 min-w-56">
        <span
          class="absolute -translate-y-1/2 i-lucide-search size-4 left-3 top-1/2 text-n-slate-10"
        />
        <input
          v-model="search"
          type="search"
          class="!mb-0 !h-9 !pl-9 text-sm rounded-lg"
          :placeholder="$t('CRM.CONNECTIONS.SEARCH')"
        />
      </div>
      <select v-model="creator" class="!mb-0 !w-auto min-w-48 !h-9 text-sm">
        <option value="">{{ $t('CRM.CONNECTIONS.ANY_CREATOR') }}</option>
        <option v-for="person in creators" :key="person.id" :value="person.id">
          {{ person.name }}
        </option>
        <option value="unknown">
          {{ $t('CRM.CONNECTIONS.UNKNOWN_CREATOR') }}
        </option>
      </select>
      <select
        v-model="statusFilter"
        class="!mb-0 !w-auto min-w-40 !h-9 text-sm"
      >
        <option value="">{{ $t('CRM.CONNECTIONS.ANY_STATUS') }}</option>
        <option v-for="(_, status) in STATUS" :key="status" :value="status">
          {{ statusLabel(status) }}
        </option>
      </select>
    </div>

    <woot-loading-state
      v-if="isLoading && !connections.length"
      :message="$t('CRM.COMMON.LOADING')"
    />
    <div
      v-else-if="!filtered.length"
      class="flex flex-col items-center gap-3 px-6 py-16 mt-6 text-center border border-dashed rounded-xl border-n-weak"
    >
      <span class="i-lucide-smartphone size-8 text-n-slate-10" />
      <p class="text-sm text-n-slate-11">
        {{
          connections.length
            ? $t('CRM.CONNECTIONS.NO_MATCH')
            : $t('CRM.CONNECTIONS.EMPTY')
        }}
      </p>
    </div>
    <div v-else class="grid gap-3 mt-6 lg:grid-cols-2">
      <article
        v-for="(connection, index) in filtered"
        :key="connection.id"
        class="flex flex-col gap-4 p-5 border rounded-xl border-n-weak bg-n-solid-1 alvo-rise alvo-card"
        :style="{ '--alvo-delay': `${240 + index * 60}ms` }"
      >
        <header class="flex items-start justify-between gap-3">
          <div class="flex items-start min-w-0 gap-3">
            <span
              class="flex items-center justify-center rounded-xl size-10 shrink-0 bg-n-teal-3 text-n-teal-11"
            >
              <span class="i-ri-whatsapp-line size-5" />
            </span>
            <div class="min-w-0">
              <h3 class="text-sm font-semibold truncate text-n-slate-12">
                {{ connection.name }}
              </h3>
              <p class="text-sm text-n-slate-11">
                {{ formatPhone(connection.phone) }}
              </p>
            </div>
          </div>
          <span
            class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium rounded-full shrink-0"
            :class="STATUS[connection.status]?.pill"
          >
            <span
              class="rounded-full size-1.5"
              :class="STATUS[connection.status]?.dot"
            />
            {{ statusLabel(connection.status) }}
          </span>
        </header>

        <p
          v-if="connection.status_error"
          class="flex gap-2 p-3 -mt-1 text-xs rounded-lg bg-n-alpha-1 text-n-slate-11"
        >
          <span class="i-lucide-info size-4 shrink-0 text-n-slate-10" />
          <span class="break-words">{{ connection.status_error }}</span>
        </p>

        <dl class="grid grid-cols-2 text-sm gap-x-4 gap-y-3">
          <div>
            <dt class="text-xs text-n-slate-11">
              {{ $t('CRM.CONNECTIONS.CREATED_BY') }}
            </dt>
            <dd class="mt-0.5 text-n-slate-12 truncate">
              {{
                connection.created_by?.name ||
                $t('CRM.CONNECTIONS.UNKNOWN_CREATOR')
              }}
            </dd>
          </div>
          <div>
            <dt class="text-xs text-n-slate-11">
              {{ $t('CRM.CONNECTIONS.CREATED_AT') }}
            </dt>
            <dd class="mt-0.5 text-n-slate-12">
              {{ formatDate(connection.created_at) }}
            </dd>
          </div>
          <div>
            <dt class="text-xs text-n-slate-11">
              {{ $t('CRM.CONNECTIONS.OWNER') }}
            </dt>
            <dd class="mt-0.5 text-n-slate-12 truncate">
              {{ connection.owner?.name || $t('CRM.CONNECTIONS.NO_OWNER') }}
            </dd>
          </div>
          <div>
            <dt class="text-xs text-n-slate-11">
              {{ $t('CRM.CONNECTIONS.TEAM') }}
            </dt>
            <dd class="mt-0.5 text-n-slate-12 truncate">
              {{ connection.team?.name || $t('CRM.CONNECTIONS.NO_TEAM') }}
            </dd>
          </div>
          <div>
            <dt class="text-xs text-n-slate-11">
              {{ $t('CRM.CONNECTIONS.PROVIDER') }}
            </dt>
            <dd class="mt-0.5 text-n-slate-12">
              {{ providerLabel(connection.provider) }}
            </dd>
          </div>
          <div>
            <dt class="text-xs text-n-slate-11">
              {{ $t('CRM.CONNECTIONS.OPEN_CONVERSATIONS') }}
            </dt>
            <dd class="mt-0.5 text-n-slate-12">
              {{ connection.open_conversations }}
            </dd>
          </div>
          <div>
            <dt class="text-xs text-n-slate-11">
              {{ $t('CRM.CONNECTIONS.LAST_ACTIVITY') }}
            </dt>
            <dd class="mt-0.5 text-n-slate-12">
              {{ formatDate(connection.last_activity_at) }}
            </dd>
          </div>
        </dl>

        <p
          v-if="connection.history_import"
          class="flex items-center gap-2 -mt-1 text-xs text-n-slate-11"
        >
          <span
            class="size-4 shrink-0"
            :class="
              ['queued', 'running'].includes(connection.history_import.status)
                ? 'i-lucide-loader-circle animate-spin'
                : connection.history_import.status === 'failed'
                  ? 'i-lucide-circle-alert text-n-ruby-11'
                  : 'i-lucide-history text-n-teal-11'
            "
          />
          {{ historyText(connection) }}
        </p>

        <footer
          class="flex flex-wrap justify-end gap-2 pt-4 border-t border-n-weak"
        >
          <Button
            v-if="
              connection.provider === 'wppconnect' &&
              connection.status === 'connected'
            "
            icon="i-lucide-history"
            size="sm"
            variant="faded"
            color="slate"
            :disabled="
              ['queued', 'running'].includes(connection.history_import?.status)
            "
            :label="$t('CRM.CONNECTIONS.HISTORY.IMPORT')"
            @click="importHistory(connection)"
          />
          <Button
            v-if="canReconnect(connection)"
            :icon="
              ['needs_qr', 'connecting'].includes(connection.status)
                ? 'i-lucide-qr-code'
                : 'i-lucide-plug-zap'
            "
            size="sm"
            :label="
              ['needs_qr', 'connecting'].includes(connection.status)
                ? $t('CRM.CONNECTIONS.SHOW_QR')
                : $t('CRM.CONNECTIONS.RECONNECT')
            "
            @click="reconnect(connection)"
          />
          <Button
            icon="i-lucide-settings-2"
            size="sm"
            variant="faded"
            color="slate"
            :label="$t('CRM.CONNECTIONS.SETTINGS')"
            @click="openSettings(connection)"
          />
        </footer>
      </article>
    </div>

    <ConnectNumberWizard
      v-if="showWizard"
      :account-id="accountId"
      @close="showWizard = false"
      @created="onNumberCreated"
    />

    <woot-modal :show="!!form" :on-close="closeForm">
      <form v-if="form" class="crm-modal-form" @submit.prevent="saveForm">
        <woot-modal-header
          :header-title="
            form.id
              ? $t('CRM.CONNECTIONS.SETTINGS_TITLE')
              : $t('CRM.CONNECTIONS.CREATE_TITLE')
          "
          :header-content="
            form.id
              ? $t('CRM.CONNECTIONS.SETTINGS_DESCRIPTION')
              : $t('CRM.CONNECTIONS.CREATE_DESCRIPTION')
          "
        />
        <label>
          {{ $t('CRM.CONNECTIONS.NAME') }}
          <input
            v-model="form.name"
            type="text"
            required
            :disabled="form.id && !form.canManage"
            :placeholder="$t('CRM.CONNECTIONS.NAME_PLACEHOLDER')"
          />
        </label>
        <label>
          {{ $t('CRM.CONNECTIONS.TEAM') }}
          <select v-model="form.team_id" :disabled="form.id && !form.canManage">
            <option value="">{{ $t('CRM.CONNECTIONS.NO_TEAM') }}</option>
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ team.name }}
            </option>
          </select>
        </label>
        <p class="crm-form-help">{{ $t('CRM.CONNECTIONS.TEAM_HELP') }}</p>
        <label v-if="form.id">
          {{ $t('CRM.CONNECTIONS.OWNER') }}
          <select v-model="form.owner_id" :disabled="!form.canManage">
            <option value="">{{ $t('CRM.CONNECTIONS.NO_OWNER') }}</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </label>
        <p v-if="form.id" class="crm-form-help">
          {{ $t('CRM.CONNECTIONS.OWNER_HELP') }}
        </p>
        <p
          v-if="form.id && !form.canManage"
          class="p-3 text-xs rounded-lg bg-n-amber-2 text-n-amber-11"
        >
          {{ $t('CRM.CONNECTIONS.READ_ONLY') }}
        </p>
        <div class="crm-form-actions">
          <Button
            v-if="form.id && form.canManage && !form.hasConversations"
            type="button"
            variant="faded"
            color="ruby"
            icon="i-lucide-trash-2"
            class="ltr:mr-auto rtl:ml-auto"
            :is-loading="isDeleting"
            :label="$t('CRM.CONNECTIONS.DELETE')"
            @click="deleteConnection"
          />
          <Button
            v-if="form.id && isAdmin"
            type="button"
            variant="faded"
            color="slate"
            icon="i-lucide-settings-2"
            :label="$t('CRM.CONNECTIONS.ADVANCED')"
            @click="advancedSettings"
          />
          <Button
            type="button"
            variant="faded"
            color="slate"
            :label="$t('CRM.COMMON.CANCEL')"
            @click="closeForm"
          />
          <Button
            v-if="!form.id || form.canManage"
            type="submit"
            :icon="form.id ? 'i-lucide-check' : 'i-lucide-qr-code'"
            :is-loading="isSaving"
            :label="
              form.id
                ? $t('CRM.COMMON.SAVE')
                : $t('CRM.CONNECTIONS.CREATE_SUBMIT')
            "
          />
        </div>
      </form>
    </woot-modal>

    <woot-modal :show="!!qrSession" :on-close="closeQr">
      <div v-if="qrSession" class="crm-modal-form">
        <woot-modal-header
          :header-title="$t('CRM.CONNECTIONS.QR_TITLE')"
          :header-content="
            $t('CRM.CONNECTIONS.QR_DESCRIPTION', {
              name: qrSession.connection.name,
            })
          "
        />
        <div class="flex flex-col items-center gap-4">
          <img
            v-if="qrSession.qr"
            :src="qrSession.qr"
            :alt="$t('CRM.CONNECTIONS.QR_TITLE')"
            class="p-3 bg-white rounded-xl size-64"
          />
          <div
            v-else
            class="flex flex-col items-center justify-center gap-3 text-sm rounded-xl size-64 bg-n-alpha-1 text-n-slate-11"
          >
            <span class="i-lucide-loader-circle size-6 animate-spin" />
            {{ $t('CRM.CONNECTIONS.QR_GENERATING') }}
          </div>
          <ol
            class="flex flex-col gap-1.5 text-sm list-decimal list-inside text-n-slate-11"
          >
            <li>{{ $t('CRM.CONNECTIONS.QR_STEP_1') }}</li>
            <li>{{ $t('CRM.CONNECTIONS.QR_STEP_2') }}</li>
            <li>{{ $t('CRM.CONNECTIONS.QR_STEP_3') }}</li>
          </ol>
          <p class="flex items-center gap-2 text-xs text-n-slate-11">
            <span class="i-lucide-loader-circle size-4 animate-spin" />
            {{ $t('CRM.CONNECTIONS.QR_WAITING') }}
          </p>
        </div>
        <div class="crm-form-actions">
          <Button
            variant="faded"
            color="slate"
            :label="$t('CRM.COMMON.CLOSE')"
            @click="closeQr"
          />
        </div>
      </div>
    </woot-modal>
  </section>
</template>
