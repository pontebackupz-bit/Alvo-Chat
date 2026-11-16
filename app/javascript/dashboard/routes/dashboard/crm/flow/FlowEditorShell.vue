<script setup>
import { ref, watch } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';

// Full-screen frame shared by the flow editors: title bar with save and a
// discard confirmation, the board in the default slot and a side panel.
const props = defineProps({
  subtitle: { type: String, default: '' },
  isDirty: { type: Boolean, default: false },
  isSaving: { type: Boolean, default: false },
  saveLabel: { type: String, required: true },
});

const emit = defineEmits(['save', 'close', 'edit']);

const name = defineModel('name', { type: String, required: true });

const confirmDiscard = ref(false);

watch(
  () => props.isDirty,
  () => {
    confirmDiscard.value = false;
  }
);

const close = () => {
  if (props.isDirty && !confirmDiscard.value) {
    confirmDiscard.value = true;
    return;
  }
  emit('close');
};
</script>

<template>
  <div class="fixed inset-0 z-50 flex flex-col bg-n-background">
    <header
      class="flex flex-wrap items-center gap-3 px-4 py-2.5 border-b border-n-weak bg-n-solid-1"
    >
      <Button
        icon="i-lucide-arrow-left"
        color="slate"
        variant="ghost"
        size="sm"
        :aria-label="$t('CRM.FLOW_CANVAS.BACK')"
        @click="close"
      />
      <div class="flex flex-col flex-1 min-w-48">
        <input
          v-model="name"
          class="h-8 px-2 text-base font-semibold bg-transparent rounded-lg outline-none text-n-slate-12 hover:bg-n-alpha-1 focus:bg-n-alpha-1"
          :aria-label="$t('CRM.FLOW_CANVAS.NAME')"
          @input="emit('edit')"
        />
        <p v-if="subtitle" class="px-2 text-xs truncate text-n-slate-11">
          {{ subtitle }}
        </p>
      </div>
      <span
        v-if="isDirty"
        class="flex items-center gap-1.5 text-xs whitespace-nowrap text-n-amber-11"
      >
        <span class="rounded-full size-1.5 bg-n-amber-9" />
        {{ $t('CRM.FLOW_CANVAS.UNSAVED') }}
      </span>
      <slot name="actions" />
      <Button
        icon="i-lucide-save"
        size="sm"
        :label="saveLabel"
        :is-loading="isSaving"
        @click="emit('save')"
      />
    </header>

    <div
      v-if="confirmDiscard"
      class="flex items-center justify-between gap-3 px-4 py-2 text-sm bg-n-amber-3 text-n-amber-11"
    >
      <span>{{ $t('CRM.FLOW_CANVAS.DISCARD_CONFIRM') }}</span>
      <div class="flex gap-2">
        <Button
          size="xs"
          color="slate"
          variant="faded"
          :label="$t('CRM.FLOW_CANVAS.KEEP_EDITING')"
          @click="confirmDiscard = false"
        />
        <Button
          size="xs"
          color="ruby"
          :label="$t('CRM.FLOW_CANVAS.DISCARD')"
          @click="close"
        />
      </div>
    </div>

    <div class="flex flex-1 min-h-0">
      <slot />
      <aside
        class="flex flex-col gap-4 p-5 overflow-y-auto border-l w-80 border-n-weak bg-n-solid-1"
      >
        <slot name="sidebar" />
      </aside>
    </div>
  </div>
</template>
