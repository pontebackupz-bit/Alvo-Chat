<script>
// One picture request per number, shared by every contact card.
const pictureRequests = new Map();
</script>

<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import crmAPI from 'dashboard/api/crm';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useMessageContext } from '../provider.js';
import BaseAttachmentBubble from './BaseAttachment.vue';

import {
  DuplicateContactException,
  ExceptionWithMessage,
} from 'shared/helpers/CustomErrors';

const { attachments, inboxId } = useMessageContext();
const router = useRouter();
const isStarting = ref(false);
const pictureUrl = ref('');
const pictureFailed = ref(false);

const $store = useStore();
const { t } = useI18n();

const attachment = computed(() => {
  return attachments.value[0];
});

const phoneNumber = computed(() => {
  return attachment.value.fallbackTitle;
});

const contactName = computed(() => {
  const { meta } = attachment.value ?? {};
  const { firstName, lastName } = meta ?? {};
  return `${firstName ?? ''} ${lastName ?? ''}`.trim();
});

const formattedPhoneNumber = computed(() => {
  return phoneNumber.value.replace(/\s|-|[A-Za-z]/g, '');
});

const rawPhoneNumber = computed(() => {
  return phoneNumber.value.replace(/\D/g, '');
});

function getContactObject() {
  const contactItem = {
    name: contactName.value,
    phone_number: `+${rawPhoneNumber.value}`,
  };
  return contactItem;
}

async function filterContactByNumber(searchCandidate) {
  const query = {
    attribute_key: 'phone_number',
    filter_operator: 'equal_to',
    values: [searchCandidate],
    attribute_model: 'standard',
    custom_attribute_type: '',
  };

  const queryPayload = { payload: [query] };
  const contacts = await $store.dispatch('contacts/filter', {
    queryPayload,
    resetState: false,
  });
  return contacts.shift();
}

function openContactNewTab(contactId) {
  const accountId = window.location.pathname.split('/')[3];
  const url = `/app/accounts/${accountId}/contacts/${contactId}`;
  window.open(url, '_blank');
}

async function addContact() {
  try {
    let contact = await filterContactByNumber(rawPhoneNumber);
    if (!contact) {
      contact = await $store.dispatch('contacts/create', getContactObject());
      useAlert(t('CONTACT_FORM.SUCCESS_MESSAGE'));
    }
    openContactNewTab(contact.id);
  } catch (error) {
    if (error instanceof DuplicateContactException) {
      if (error.data.includes('phone_number')) {
        useAlert(t('CONTACT_FORM.FORM.PHONE_NUMBER.DUPLICATE'));
      }
    } else if (error instanceof ExceptionWithMessage) {
      useAlert(error.data);
    } else {
      useAlert(t('CONTACT_FORM.ERROR_MESSAGE'));
    }
  }
}

const action = computed(() => ({
  label: t('CONVERSATION.SAVE_CONTACT'),
  onClick: addContact,
}));

// Opens (or reuses) a conversation with the shared number on this WhatsApp.
async function startConversation() {
  if (isStarting.value) return;
  isStarting.value = true;
  try {
    const accountId = Number(window.location.pathname.split('/')[3]);
    const { data } = await crmAPI.startConversation(accountId, {
      inbox_id: inboxId.value,
      phone: rawPhoneNumber.value,
      name: contactName.value,
    });
    router.push(frontendURL(conversationUrl({ accountId, id: data.id })));
  } catch (error) {
    useAlert(error.response?.data?.error || t('CONVERSATION.START_CHAT_ERROR'));
  } finally {
    isStarting.value = false;
  }
}

onMounted(async () => {
  const phone = rawPhoneNumber.value;
  if (phone.length < 8 || !inboxId.value) return;
  const key = `${inboxId.value}:${phone}`;
  if (!pictureRequests.has(key)) {
    const accountId = Number(window.location.pathname.split('/')[3]);
    pictureRequests.set(
      key,
      crmAPI
        .getContactPicture(accountId, { inbox_id: inboxId.value, phone })
        .then(({ data }) => data.url || '')
        .catch(() => '')
    );
  }
  pictureUrl.value = await pictureRequests.get(key);
});

const showPicture = computed(() => pictureUrl.value && !pictureFailed.value);

const chatAction = computed(() =>
  rawPhoneNumber.value.length >= 8
    ? {
        label: t('CONVERSATION.START_CHAT'),
        icon: 'i-lucide-message-circle',
        loading: isStarting.value,
        onClick: startConversation,
      }
    : null
);
</script>

<template>
  <BaseAttachmentBubble
    icon="i-teenyicons-user-circle-solid"
    :icon-bg-color="showPicture ? 'bg-n-alpha-3' : 'bg-[#D6409F]'"
    :icon-class="showPicture ? 'size-12 rounded-full' : 'size-8 rounded-lg'"
    sender-translation-key="CONVERSATION.SHARED_ATTACHMENT.CONTACT"
    :title="contactName"
    :content="phoneNumber"
    :action="formattedPhoneNumber ? action : null"
    :primary-action="chatAction"
  >
    <template v-if="showPicture" #icon>
      <img
        :src="pictureUrl"
        :alt="contactName"
        class="size-12 object-cover"
        @error="pictureFailed = true"
      />
    </template>
  </BaseAttachmentBubble>
</template>
