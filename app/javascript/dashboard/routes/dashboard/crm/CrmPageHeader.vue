<script setup>
import BaseSettingsHeader from '../settings/components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  title: { type: String, required: true },
  description: { type: String, required: true },
  actionLabel: { type: String, default: '' },
  actionIcon: { type: String, default: '' },
  actionDisabled: { type: Boolean, default: false },
});

defineEmits(['action']);
</script>

<template>
  <BaseSettingsHeader :title="title" :description="description">
    <template v-if="actionLabel" #actions>
      <Button
        :label="actionLabel"
        :icon="actionIcon"
        size="sm"
        :disabled="actionDisabled"
        @click="$emit('action')"
      />
    </template>
  </BaseSettingsHeader>
</template>
