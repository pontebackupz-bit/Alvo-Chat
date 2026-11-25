<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import BaseBubble from './Base.vue';
import Icon from 'next/icon/Icon.vue';
import { useMessageContext } from '../provider.js';

defineProps({
  icon: { type: [String, Object], required: true },
  iconBgColor: { type: String, default: 'bg-n-alpha-3' },
  iconClass: { type: String, default: 'size-8 rounded-lg' },
  senderTranslationKey: { type: String, required: true },
  content: { type: String, required: true },
  title: { type: String, default: '' }, // Title can be any name, description, etc
  action: {
    type: Object,
    required: true,
    validator: action => {
      return action.label && (action.href || action.onClick);
    },
  },
  // Main action shown first, highlighted (e.g. "Conversar").
  primaryAction: {
    type: Object,
    default: null,
  },
});

const { sender } = useMessageContext();
const { t } = useI18n();

const senderName = computed(() => {
  return sender?.value?.name || '';
});
</script>

<template>
  <BaseBubble class="overflow-hidden p-3" data-bubble-name="attachment">
    <div class="grid gap-4 min-w-64">
      <div class="grid gap-3">
        <div
          class="grid place-content-center overflow-hidden"
          :class="[iconClass, iconBgColor]"
        >
          <slot name="icon">
            <Icon :icon="icon" class="text-white size-4" />
          </slot>
        </div>
        <div class="space-y-1 overflow-hidden">
          <div v-if="senderName" class="text-n-slate-12 text-sm truncate">
            {{
              t(senderTranslationKey, {
                sender: senderName,
              })
            }}
          </div>
          <slot>
            <div v-if="title" class="truncate text-sm text-n-slate-12">
              {{ title }}
            </div>
            <div v-if="content" class="truncate text-sm text-n-slate-11">
              {{ content }}
            </div>
          </slot>
        </div>
      </div>
      <div v-if="action || primaryAction" class="mb-2 grid gap-2">
        <button
          v-if="primaryAction"
          class="w-full flex items-center justify-center gap-2 bg-n-brand text-white px-4 py-2 rounded-lg text-sm font-medium hover:brightness-110 disabled:opacity-60 transition"
          :disabled="primaryAction.loading"
          @click="primaryAction.onClick"
        >
          <Icon
            v-if="primaryAction.icon"
            :icon="primaryAction.icon"
            class="size-4"
          />
          {{ primaryAction.label }}
        </button>
        <a
          v-if="action?.href"
          :href="action.href"
          rel="noreferrer noopener nofollow"
          target="_blank"
          class="w-full block bg-n-solid-3 px-4 py-2 rounded-lg text-sm text-center border border-n-container"
        >
          {{ action.label }}
        </a>
        <button
          v-else-if="action"
          class="w-full bg-n-solid-3 px-4 py-2 rounded-lg text-sm text-center border border-n-container"
          @click="action.onClick"
        >
          {{ action.label }}
        </button>
      </div>
    </div>
  </BaseBubble>
</template>
