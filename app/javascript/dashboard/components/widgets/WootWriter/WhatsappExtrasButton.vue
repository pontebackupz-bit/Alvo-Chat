<script setup>
// "+" in the reply box of WhatsApp numbers connected by QR code: sends a
// location, a contact card, a poll or an option list (the WhatsApp "form"
// available outside the official API).
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { vOnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'next/icon/Icon.vue';
import crmAPI from 'dashboard/api/crm';
import ContactsAPI from 'dashboard/api/contacts';

const props = defineProps({
  inbox: { type: Object, default: () => ({}) },
  conversationId: { type: [Number, String], default: null },
});

const { t } = useI18n();
const accountId = useMapGetter('getCurrentAccountId');

const KINDS = [
  { key: 'location', icon: 'i-lucide-map-pin' },
  { key: 'contact', icon: 'i-lucide-contact' },
  { key: 'poll', icon: 'i-lucide-chart-bar-big' },
  { key: 'list', icon: 'i-lucide-list-checks' },
];
const POLL_MAX = 12;
const LIST_MAX = 10;

const isAvailable = computed(
  () =>
    props.inbox?.additional_attributes?.provider === 'wppconnect' &&
    !!props.conversationId
);

const showMenu = ref(false);
const kind = ref('');
const isSending = ref(false);
const isLocating = ref(false);

const emptyForm = () => ({
  lat: '',
  lng: '',
  name: '',
  address: '',
  mapsLink: '',
  phone: '',
  question: '',
  options: ['', ''],
  multiple: false,
  description: '',
  buttonText: '',
  sectionTitle: '',
  rows: [{ title: '', description: '' }],
});
const form = ref(emptyForm());

const contactQuery = ref('');
const contactResults = ref([]);
let searchTimer = null;

const open = key => {
  showMenu.value = false;
  form.value = emptyForm();
  contactQuery.value = '';
  contactResults.value = [];
  kind.value = key;
};
const close = () => {
  kind.value = '';
};

const title = computed(() =>
  kind.value ? t(`WHATSAPP_EXTRAS.${kind.value.toUpperCase()}.TITLE`) : ''
);
const description = computed(() =>
  kind.value ? t(`WHATSAPP_EXTRAS.${kind.value.toUpperCase()}.DESCRIPTION`) : ''
);

// Google Maps / WhatsApp links: "@-15.79,-47.88", "q=-15.79,-47.88",
// "!3d-15.79!4d-47.88" or just "-15.79, -47.88".
const parseCoordinates = text => {
  const patterns = [
    /!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)/,
    /@(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/,
    /[?&](?:q|query|ll|destination)=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/,
    /^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/,
  ];
  const match = patterns.map(p => text.match(p)).find(Boolean);
  return match ? { lat: match[1], lng: match[2] } : null;
};

watch(
  () => form.value.mapsLink,
  link => {
    const coords = parseCoordinates(decodeURIComponent(link || ''));
    if (coords) Object.assign(form.value, coords);
  }
);

const useMyLocation = () => {
  if (!navigator.geolocation) {
    useAlert(t('WHATSAPP_EXTRAS.LOCATION.NO_GPS'));
    return;
  }
  isLocating.value = true;
  navigator.geolocation.getCurrentPosition(
    ({ coords }) => {
      form.value.lat = coords.latitude.toFixed(6);
      form.value.lng = coords.longitude.toFixed(6);
      isLocating.value = false;
    },
    () => {
      useAlert(t('WHATSAPP_EXTRAS.LOCATION.NO_GPS'));
      isLocating.value = false;
    },
    { enableHighAccuracy: true, timeout: 10000 }
  );
};

const mapUrl = computed(() =>
  form.value.lat && form.value.lng
    ? `https://www.google.com/maps?q=${form.value.lat},${form.value.lng}`
    : ''
);

watch(contactQuery, query => {
  clearTimeout(searchTimer);
  if (query.trim().length < 2) {
    contactResults.value = [];
    return;
  }
  searchTimer = setTimeout(async () => {
    try {
      const { data } = await ContactsAPI.search(query.trim());
      contactResults.value = (data.payload || [])
        .filter(contact => contact.phone_number)
        .slice(0, 6);
    } catch (_) {
      contactResults.value = [];
    }
  }, 300);
});

const pickContact = contact => {
  form.value.name = contact.name;
  form.value.phone = contact.phone_number;
  contactQuery.value = '';
  contactResults.value = [];
};

const addOption = () => {
  if (form.value.options.length < POLL_MAX) form.value.options.push('');
};
const removeOption = index => form.value.options.splice(index, 1);
const addRow = () => {
  if (form.value.rows.length < LIST_MAX)
    form.value.rows.push({ title: '', description: '' });
};
const removeRow = index => form.value.rows.splice(index, 1);

const payload = computed(() => {
  const f = form.value;
  switch (kind.value) {
    case 'location':
      return { lat: f.lat, lng: f.lng, name: f.name, address: f.address };
    case 'contact':
      return { name: f.name, phone: f.phone };
    case 'poll':
      return { name: f.question, options: f.options, multiple: f.multiple };
    case 'list':
      return {
        description: f.description,
        button_text: f.buttonText,
        section_title: f.sectionTitle,
        rows: f.rows,
      };
    default:
      return {};
  }
});

const canSend = computed(() => {
  const f = form.value;
  if (kind.value === 'location') return !!(f.lat && f.lng);
  if (kind.value === 'contact') return f.phone.replace(/\D/g, '').length >= 10;
  if (kind.value === 'poll')
    return f.question.trim() && f.options.filter(o => o.trim()).length >= 2;
  if (kind.value === 'list')
    return f.description.trim() && f.rows.some(row => row.title.trim());
  return false;
});

const send = async () => {
  if (!canSend.value || isSending.value) return;
  isSending.value = true;
  try {
    await crmAPI.sendRichMessage(accountId.value, props.conversationId, {
      kind: kind.value,
      ...payload.value,
    });
    useAlert(t('WHATSAPP_EXTRAS.SENT'), { status: 'success' });
    close();
  } catch (error) {
    useAlert(error.response?.data?.error || t('WHATSAPP_EXTRAS.ERROR'), {
      status: 'error',
    });
  } finally {
    isSending.value = false;
  }
};

const inputClass =
  'block w-full min-w-0 !mb-0 h-10 px-3 text-sm text-n-slate-12 bg-n-alpha-black2 rounded-lg outline outline-1 outline-n-weak outline-offset-[-1px] hover:outline-n-slate-6 focus:outline-n-brand';
const labelClass = 'flex flex-col gap-2 text-sm font-medium text-n-slate-12';
</script>

<template>
  <div v-if="isAvailable" class="relative">
    <Button
      v-tooltip.top-end="$t('WHATSAPP_EXTRAS.TOOLTIP')"
      icon="i-lucide-circle-plus"
      slate
      faded
      sm
      @click="showMenu = !showMenu"
    />
    <div
      v-if="showMenu"
      v-on-click-outside="() => (showMenu = false)"
      class="absolute z-30 flex flex-col p-1 border shadow-lg bottom-full mb-2 ltr:left-0 rtl:right-0 w-56 rounded-xl bg-n-solid-2 border-n-weak"
    >
      <button
        v-for="item in KINDS"
        :key="item.key"
        type="button"
        class="flex items-center gap-2.5 px-3 py-2 text-sm text-left rounded-lg text-n-slate-12 hover:bg-n-alpha-2"
        @click="open(item.key)"
      >
        <Icon :icon="item.icon" class="size-4 text-n-slate-11" />
        {{ $t(`WHATSAPP_EXTRAS.${item.key.toUpperCase()}.MENU`) }}
      </button>
    </div>

    <woot-modal :show="!!kind" :on-close="close">
      <form class="flex flex-col gap-5 px-8 pb-8" @submit.prevent="send">
        <woot-modal-header
          class="!px-0"
          :header-title="title"
          :header-content="description"
        />

        <template v-if="kind === 'location'">
          <div class="flex flex-wrap gap-2">
            <Button
              type="button"
              icon="i-lucide-locate-fixed"
              variant="faded"
              color="slate"
              size="sm"
              :is-loading="isLocating"
              :label="$t('WHATSAPP_EXTRAS.LOCATION.MY_LOCATION')"
              @click="useMyLocation"
            />
          </div>
          <label :class="labelClass">
            {{ $t('WHATSAPP_EXTRAS.LOCATION.LINK') }}
            <input
              v-model="form.mapsLink"
              :class="inputClass"
              :placeholder="$t('WHATSAPP_EXTRAS.LOCATION.LINK_PLACEHOLDER')"
            />
          </label>
          <div class="grid grid-cols-2 gap-3">
            <label :class="labelClass">
              {{ $t('WHATSAPP_EXTRAS.LOCATION.LAT') }}
              <input
                v-model="form.lat"
                :class="inputClass"
                inputmode="decimal"
                :placeholder="$t('WHATSAPP_EXTRAS.LOCATION.LAT_PLACEHOLDER')"
              />
            </label>
            <label :class="labelClass">
              {{ $t('WHATSAPP_EXTRAS.LOCATION.LNG') }}
              <input
                v-model="form.lng"
                :class="inputClass"
                inputmode="decimal"
                :placeholder="$t('WHATSAPP_EXTRAS.LOCATION.LNG_PLACEHOLDER')"
              />
            </label>
          </div>
          <label :class="labelClass">
            {{ $t('WHATSAPP_EXTRAS.LOCATION.NAME') }}
            <input
              v-model="form.name"
              :class="inputClass"
              maxlength="100"
              :placeholder="$t('WHATSAPP_EXTRAS.LOCATION.NAME_PLACEHOLDER')"
            />
          </label>
          <label :class="labelClass">
            {{ $t('WHATSAPP_EXTRAS.LOCATION.ADDRESS') }}
            <input v-model="form.address" :class="inputClass" maxlength="300" />
          </label>
          <a
            v-if="mapUrl"
            :href="mapUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="flex items-center gap-1.5 text-sm text-n-blue-11 hover:underline"
          >
            <Icon icon="i-lucide-external-link" class="size-3.5" />
            {{ $t('WHATSAPP_EXTRAS.LOCATION.PREVIEW') }}
          </a>
        </template>

        <template v-else-if="kind === 'contact'">
          <label :class="labelClass">
            {{ $t('WHATSAPP_EXTRAS.CONTACT.SEARCH') }}
            <input
              v-model="contactQuery"
              :class="inputClass"
              :placeholder="$t('WHATSAPP_EXTRAS.CONTACT.SEARCH_PLACEHOLDER')"
            />
          </label>
          <div
            v-if="contactResults.length"
            class="flex flex-col -mt-3 overflow-hidden border rounded-lg border-n-weak"
          >
            <button
              v-for="contact in contactResults"
              :key="contact.id"
              type="button"
              class="flex items-center justify-between gap-3 px-3 py-2 text-sm text-left hover:bg-n-alpha-2"
              @click="pickContact(contact)"
            >
              <span class="truncate text-n-slate-12">{{ contact.name }}</span>
              <span class="text-xs text-n-slate-11 shrink-0">
                {{ contact.phone_number }}
              </span>
            </button>
          </div>
          <label :class="labelClass">
            {{ $t('WHATSAPP_EXTRAS.CONTACT.NAME') }}
            <input v-model="form.name" :class="inputClass" maxlength="100" />
          </label>
          <label :class="labelClass">
            {{ $t('WHATSAPP_EXTRAS.CONTACT.PHONE') }}
            <input
              v-model="form.phone"
              :class="inputClass"
              inputmode="tel"
              :placeholder="$t('WHATSAPP_EXTRAS.CONTACT.PHONE_PLACEHOLDER')"
            />
          </label>
        </template>

        <template v-else-if="kind === 'poll'">
          <label :class="labelClass">
            {{ $t('WHATSAPP_EXTRAS.POLL.QUESTION') }}
            <input
              v-model="form.question"
              :class="inputClass"
              maxlength="255"
            />
          </label>
          <div class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ $t('WHATSAPP_EXTRAS.POLL.OPTIONS') }}
            </span>
            <div
              v-for="(_, index) in form.options"
              :key="index"
              class="flex items-center gap-2"
            >
              <input
                v-model="form.options[index]"
                :class="inputClass"
                maxlength="100"
                :placeholder="
                  $t('WHATSAPP_EXTRAS.POLL.OPTION', { number: index + 1 })
                "
              />
              <Button
                v-if="form.options.length > 2"
                type="button"
                icon="i-lucide-x"
                variant="ghost"
                color="slate"
                size="sm"
                @click="removeOption(index)"
              />
            </div>
            <Button
              v-if="form.options.length < POLL_MAX"
              type="button"
              icon="i-lucide-plus"
              variant="ghost"
              color="blue"
              size="sm"
              class="self-start"
              :label="$t('WHATSAPP_EXTRAS.POLL.ADD_OPTION')"
              @click="addOption"
            />
          </div>
          <label class="flex items-center gap-2 text-sm text-n-slate-12">
            <input v-model="form.multiple" type="checkbox" class="!m-0" />
            {{ $t('WHATSAPP_EXTRAS.POLL.MULTIPLE') }}
          </label>
        </template>

        <template v-else-if="kind === 'list'">
          <label :class="labelClass">
            {{ $t('WHATSAPP_EXTRAS.LIST.TEXT') }}
            <textarea
              v-model="form.description"
              rows="3"
              maxlength="1000"
              class="block w-full min-w-0 !mb-0 px-3 py-2.5 text-sm text-n-slate-12 bg-n-alpha-black2 rounded-lg outline outline-1 outline-n-weak outline-offset-[-1px] focus:outline-n-brand resize-y"
            />
          </label>
          <div class="grid grid-cols-2 gap-3">
            <label :class="labelClass">
              {{ $t('WHATSAPP_EXTRAS.LIST.BUTTON') }}
              <input
                v-model="form.buttonText"
                :class="inputClass"
                maxlength="20"
                :placeholder="$t('WHATSAPP_EXTRAS.LIST.BUTTON_PLACEHOLDER')"
              />
            </label>
            <label :class="labelClass">
              {{ $t('WHATSAPP_EXTRAS.LIST.SECTION') }}
              <input
                v-model="form.sectionTitle"
                :class="inputClass"
                maxlength="24"
                :placeholder="$t('WHATSAPP_EXTRAS.LIST.SECTION_PLACEHOLDER')"
              />
            </label>
          </div>
          <div class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ $t('WHATSAPP_EXTRAS.LIST.ROWS') }}
            </span>
            <div
              v-for="(row, index) in form.rows"
              :key="index"
              class="flex items-start gap-2"
            >
              <div class="grid flex-1 gap-2">
                <input
                  v-model="row.title"
                  :class="inputClass"
                  maxlength="24"
                  :placeholder="
                    $t('WHATSAPP_EXTRAS.LIST.ROW_TITLE', { number: index + 1 })
                  "
                />
                <input
                  v-model="row.description"
                  :class="inputClass"
                  maxlength="72"
                  :placeholder="$t('WHATSAPP_EXTRAS.LIST.ROW_DESCRIPTION')"
                />
              </div>
              <Button
                v-if="form.rows.length > 1"
                type="button"
                icon="i-lucide-x"
                variant="ghost"
                color="slate"
                size="sm"
                @click="removeRow(index)"
              />
            </div>
            <Button
              v-if="form.rows.length < LIST_MAX"
              type="button"
              icon="i-lucide-plus"
              variant="ghost"
              color="blue"
              size="sm"
              class="self-start"
              :label="$t('WHATSAPP_EXTRAS.LIST.ADD_ROW')"
              @click="addRow"
            />
          </div>
          <p class="mb-0 text-xs text-n-slate-11">
            {{ $t('WHATSAPP_EXTRAS.LIST.NOTE') }}
          </p>
        </template>

        <div class="flex justify-end gap-2">
          <Button
            type="button"
            variant="faded"
            color="slate"
            :label="$t('WHATSAPP_EXTRAS.CANCEL')"
            @click="close"
          />
          <Button
            type="submit"
            icon="i-lucide-send-horizontal"
            :is-loading="isSending"
            :disabled="!canSend"
            :label="$t('WHATSAPP_EXTRAS.SEND')"
          />
        </div>
      </form>
    </woot-modal>
  </div>
</template>
