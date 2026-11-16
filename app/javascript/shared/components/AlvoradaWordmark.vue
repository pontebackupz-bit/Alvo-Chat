<script setup>
import { computed } from 'vue';

const props = defineProps({
  tone: { type: String, default: 'blue' },
  size: { type: String, default: 'default' },
  // `icon` renders only the symbol, for tight spaces such as the sidebar.
  variant: { type: String, default: 'full' },
  subtitle: { type: Boolean, default: true },
});

const wordmark = { name: 'AlvoChat', company: 'Alvorada Distribuidora' };

const sizes = {
  default: {
    box: 'size-9',
    icon: 'size-5',
    text: 'text-xl',
    sub: 'text-[0.55rem]',
  },
  large: {
    box: 'size-11',
    icon: 'size-6',
    text: 'text-3xl',
    sub: 'text-[0.65rem]',
  },
};
const size = computed(() => sizes[props.size] || sizes.default);
const isLight = computed(() => props.tone === 'light');
const nameClass = computed(() =>
  isLight.value ? 'text-white' : 'text-[#0F2A63]'
);
const subClass = computed(() =>
  isLight.value ? 'text-blue-200' : 'text-[#64748B]'
);
</script>

<template>
  <span
    class="inline-flex select-none items-center gap-2.5"
    :aria-label="wordmark.name"
  >
    <span
      class="flex flex-shrink-0 items-center justify-center rounded-[10px] bg-gradient-to-br from-[#2A6BFF] to-[#0B3FB8] text-white shadow-[0_6px_18px_-6px_rgba(42,107,255,0.8)]"
      :class="size.box"
    >
      <span class="i-lucide-messages-square" :class="size.icon" />
    </span>
    <span v-if="variant !== 'icon'" class="flex flex-col">
      <span
        class="font-semibold leading-none tracking-[-0.04em]"
        :class="[nameClass, size.text]"
      >
        {{ wordmark.name }}
      </span>
      <span
        v-if="subtitle"
        class="mt-1 font-semibold uppercase leading-none tracking-[0.22em]"
        :class="[subClass, size.sub]"
      >
        {{ wordmark.company }}
      </span>
    </span>
  </span>
</template>
