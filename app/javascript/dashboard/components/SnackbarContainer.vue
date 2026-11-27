<script setup>
import { ref, onMounted, onUnmounted, nextTick } from 'vue';
import WootSnackbar from './Snackbar.vue';
import { emitter } from 'shared/helpers/mitt';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  duration: {
    type: Number,
    default: 3500,
  },
});

const { t } = useI18n();

const snackMessages = ref([]);
const snackbarContainer = ref(null);

const showPopover = () => {
  try {
    const el = snackbarContainer.value;
    if (el?.matches(':popover-open')) {
      el.hidePopover();
    }
    el?.showPopover();
  } catch (e) {
    // ignore
  }
};

const onNewToastMessage = ({ message: originalMessage, action }) => {
  const message = action?.usei18n ? t(originalMessage) : originalMessage;
  // Errors stay a little longer so they can be read.
  const isError = action?.status === 'error';
  const duration = action?.duration || (isError ? 5000 : props.duration);
  const key = `${Date.now()}-${Math.random()}`;

  snackMessages.value.push({ key, message, action, duration });

  nextTick(showPopover);

  setTimeout(() => {
    snackMessages.value = snackMessages.value.filter(item => item.key !== key);
  }, duration);
};

const dismiss = key => {
  snackMessages.value = snackMessages.value.filter(item => item.key !== key);
};

onMounted(() => {
  emitter.on('newToastMessage', onNewToastMessage);
});

onUnmounted(() => {
  emitter.off('newToastMessage', onNewToastMessage);
});
</script>

<template>
  <div
    ref="snackbarContainer"
    popover="manual"
    class="fixed top-4 left-1/2 -translate-x-1/2 sm:left-auto sm:right-4 sm:translate-x-0 max-w-[24rem] w-[calc(100%-2rem)] bg-transparent border-0 p-0 m-0 outline-none overflow-visible"
  >
    <transition-group name="toast-fade" tag="div">
      <WootSnackbar
        v-for="snackMessage in snackMessages"
        :key="snackMessage.key"
        :message="snackMessage.message"
        :action="snackMessage.action"
        :duration="snackMessage.duration"
        @close="dismiss(snackMessage.key)"
      />
    </transition-group>
  </div>
</template>
