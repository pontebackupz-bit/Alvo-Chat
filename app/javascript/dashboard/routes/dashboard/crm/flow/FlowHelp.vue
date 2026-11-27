<script setup>
defineProps({
  steps: { type: Array, required: true },
  note: { type: String, default: '' },
});
</script>

<template>
  <h3 class="flex items-center gap-2 text-sm font-semibold text-n-slate-12">
    <span class="i-lucide-info size-4 text-n-brand" />
    {{ $t('CRM.FLOW_CANVAS.HELP_TITLE') }}
  </h3>
  <ol class="flex flex-col gap-3">
    <li
      v-for="(step, index) in steps"
      :key="step"
      class="flex gap-3 text-sm leading-relaxed text-n-slate-11"
    >
      <span
        class="flex items-center justify-center flex-shrink-0 text-xs font-semibold rounded-full size-5 bg-n-blue-3 text-n-blue-11"
      >
        {{ index + 1 }}
      </span>
      {{ step }}
    </li>
  </ol>
  <p
    v-if="note"
    class="p-3 text-xs leading-relaxed border rounded-lg border-n-weak text-n-slate-11"
  >
    {{ note }}
  </p>
</template>
