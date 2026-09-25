<script setup>
import { computed } from 'vue';

const props = defineProps({
  tone: { type: String, default: 'blue' },
  size: { type: String, default: 'default' },
});

const wordmark = {
  company: 'Alvorada Distribuidora',
  name: 'Alvorada',
  division: 'Distribuidora',
};

const titleClasses = computed(() => {
  const tones = { blue: 'text-[#123F97]', light: 'text-white' };
  const sizes = { default: 'text-3xl', large: 'text-4xl' };

  return [
    'font-sans font-semibold leading-[0.82] tracking-[-0.075em]',
    tones[props.tone],
    sizes[props.size],
  ];
});

const subtitleClasses = computed(() => {
  const tones = { blue: 'text-[#123F97]', light: 'text-blue-100' };
  const sizes = { default: 'text-[0.52rem]', large: 'text-[0.62rem]' };

  return [
    'mt-1.5 block pl-0.5 font-sans font-bold leading-none tracking-[0.36em] uppercase',
    tones[props.tone],
    sizes[props.size],
  ];
});
</script>

<template>
  <span class="inline-flex select-none flex-col" :aria-label="wordmark.company">
    <span :class="titleClasses">{{ wordmark.name }}</span>
    <span :class="subtitleClasses">{{ wordmark.division }}</span>
  </span>
</template>
