<script setup>
import { useAttrs } from 'vue';

const attrs = useAttrs();
const wordmark = {
  company: 'Alvorada Distribuidora',
  initial: 'A',
};
</script>

<template>
  <span
    v-bind="attrs"
    class="grid place-items-center rounded-md bg-[#123F97] text-[0.58em] font-bold leading-none text-white"
    :aria-label="wordmark.company"
  >
    {{ wordmark.initial }}
  </span>
</template>
