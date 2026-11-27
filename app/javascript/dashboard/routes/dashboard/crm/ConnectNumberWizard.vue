<script setup>
// New connection, in the same steps as the inbox wizard: choose the channel,
// name it, then connect. WhatsApp uses AlvoChat's QR code flow (any profile);
// the other channels open the administrator inbox setup.
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useMapGetter } from 'dashboard/composables/store';
import { useInboxChannels } from 'dashboard/composables/useInboxChannels';
import Button from 'dashboard/components-next/button/Button.vue';
import ChannelItem from 'dashboard/components/widgets/ChannelItem.vue';
import crmAPI from 'dashboard/api/crm';

const props = defineProps({
  accountId: { type: [String, Number], required: true },
});

const emit = defineEmits(['close', 'created']);

const { t } = useI18n();
const router = useRouter();
const { isAdmin } = useAdmin();
const teams = useMapGetter('teams/getTeams');
const myTeams = useMapGetter('teams/getMyTeams');
const { channelList, enabledFeatures } = useInboxChannels();

const step = ref(1);
const name = ref('');
const teamId = ref('');
const isSaving = ref(false);

const steps = computed(() =>
  [1, 2, 3].map(number => ({
    number,
    title: t(`CRM.CONNECTIONS.WIZARD.STEP_${number}.TITLE`),
    description: t(`CRM.CONNECTIONS.WIZARD.STEP_${number}.DESCRIPTION`),
  }))
);

const chooseChannel = key => {
  if (key === 'whatsapp') {
    // The number goes to the person's own team unless they pick another.
    teamId.value = teamId.value || myTeams.value?.[0]?.id || '';
    step.value = 2;
    return;
  }
  if (!isAdmin.value) {
    useAlert(t('CRM.CONNECTIONS.WIZARD.ADMIN_ONLY'), { status: 'warning' });
    return;
  }
  emit('close');
  router.push({
    name: 'settings_inboxes_page_channel',
    params: { accountId: props.accountId, sub_page: key },
  });
};

const create = async () => {
  if (!name.value.trim()) {
    useAlert(t('CRM.CONNECTIONS.NAME_REQUIRED'), { status: 'warning' });
    return;
  }
  isSaving.value = true;
  try {
    const { data } = await crmAPI.createConnection(props.accountId, {
      name: name.value.trim(),
      team_id: teamId.value || null,
    });
    emit('created', { ...data, name: name.value.trim() });
  } catch (error) {
    useAlert(error.response?.data?.error || t('CRM.CONNECTIONS.SAVE_ERROR'), {
      status: 'error',
    });
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <woot-modal show size="medium" :on-close="() => emit('close')">
    <div class="grid min-h-[30rem] md:grid-cols-[15rem_minmax(0,1fr)]">
      <ol
        class="hidden gap-6 p-8 m-0 list-none border-r md:flex md:flex-col border-n-weak"
      >
        <li
          v-for="item in steps"
          :key="item.number"
          class="relative flex gap-3"
        >
          <span
            class="flex items-center justify-center text-xs font-semibold border rounded-full size-7 shrink-0"
            :class="
              item.number === step
                ? 'border-n-brand bg-n-brand text-white'
                : item.number < step
                  ? 'border-n-brand text-n-blue-11'
                  : 'border-n-weak text-n-slate-11'
            "
          >
            <span v-if="item.number < step" class="i-lucide-check size-3.5" />
            <template v-else>{{ item.number }}</template>
          </span>
          <span class="min-w-0">
            <span
              class="block text-sm font-medium"
              :class="
                item.number === step ? 'text-n-blue-11' : 'text-n-slate-12'
              "
            >
              {{ item.title }}
            </span>
            <span class="block mt-1 text-xs leading-5 text-n-slate-11">
              {{ item.description }}
            </span>
          </span>
        </li>
      </ol>

      <div class="flex flex-col min-w-0 p-8">
        <template v-if="step === 1">
          <h2 class="text-lg font-semibold text-n-slate-12">
            {{ $t('CRM.CONNECTIONS.WIZARD.CHOOSE_TITLE') }}
          </h2>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ $t('CRM.CONNECTIONS.WIZARD.CHOOSE_DESCRIPTION') }}
          </p>
          <div
            class="grid grid-cols-1 gap-4 mt-6 sm:grid-cols-2 lg:grid-cols-3"
          >
            <ChannelItem
              v-for="channel in channelList"
              :key="channel.key"
              :channel="channel"
              :enabled-features="enabledFeatures"
              @channel-item-click="chooseChannel"
            />
          </div>
        </template>

        <form
          v-else
          class="flex flex-col flex-1 gap-5"
          @submit.prevent="create"
        >
          <div>
            <h2 class="text-lg font-semibold text-n-slate-12">
              {{ $t('CRM.CONNECTIONS.CREATE_TITLE') }}
            </h2>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ $t('CRM.CONNECTIONS.CREATE_DESCRIPTION') }}
            </p>
          </div>
          <label
            class="flex flex-col gap-2 text-sm font-medium text-n-slate-12"
          >
            {{ $t('CRM.CONNECTIONS.NAME') }}
            <input
              v-model="name"
              type="text"
              required
              class="!mb-0"
              :placeholder="$t('CRM.CONNECTIONS.NAME_PLACEHOLDER')"
            />
          </label>
          <label
            class="flex flex-col gap-2 text-sm font-medium text-n-slate-12"
          >
            {{ $t('CRM.CONNECTIONS.TEAM') }}
            <select v-model="teamId" class="!mb-0">
              <option value="">{{ $t('CRM.CONNECTIONS.NO_TEAM') }}</option>
              <option v-for="team in teams" :key="team.id" :value="team.id">
                {{ team.name }}
              </option>
            </select>
            <span class="text-xs font-normal text-n-slate-11">
              {{ $t('CRM.CONNECTIONS.TEAM_HELP') }}
            </span>
          </label>
          <div
            class="flex justify-between gap-3 pt-5 mt-auto border-t border-n-weak"
          >
            <Button
              type="button"
              variant="faded"
              color="slate"
              icon="i-lucide-arrow-left"
              :label="$t('CRM.CONNECTIONS.WIZARD.BACK')"
              @click="step = 1"
            />
            <Button
              type="submit"
              icon="i-lucide-qr-code"
              :is-loading="isSaving"
              :label="$t('CRM.CONNECTIONS.CREATE_SUBMIT')"
            />
          </div>
        </form>
      </div>
    </div>
  </woot-modal>
</template>
