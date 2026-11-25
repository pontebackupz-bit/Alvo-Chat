<script setup>
// "Perguntar ao Copiloto": a chat with the AI (Groq) about the open
// conversation. Opened from the header or the reply box AI menu; answers can
// go straight into the reply.
import { computed, nextTick, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useEmitter } from 'dashboard/composables/emitter';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import Button from 'dashboard/components-next/button/Button.vue';
import crmAPI from 'dashboard/api/crm';

const props = defineProps({
  chat: { type: Object, required: true },
  inbox: { type: Object, default: () => ({}) },
});

const { t } = useI18n();
const accountId = useMapGetter('getCurrentAccountId');
const show = ref(false);
const question = ref('');
const turns = ref([]);
const isAsking = ref(false);
const error = ref('');
const listRef = ref(null);
const inputRef = ref(null);

const suggestions = computed(() => [
  t('ATTENDANCE.COPILOT.SUGGESTIONS.WANTS'),
  t('ATTENDANCE.COPILOT.SUGGESTIONS.PENDING'),
  t('ATTENDANCE.COPILOT.SUGGESTIONS.REPLY'),
]);

const richEditor = computed(() =>
  ['Channel::WebWidget', 'Channel::Email'].includes(props.inbox?.channel_type)
);

const scrollToEnd = async () => {
  await nextTick();
  if (listRef.value) listRef.value.scrollTop = listRef.value.scrollHeight;
};

const open = async () => {
  show.value = true;
  error.value = '';
  await nextTick();
  inputRef.value?.focus();
};

useEmitter(BUS_EVENTS.OPEN_CRM_COPILOT, open);

// A new conversation starts a new chat with the copilot.
watch(
  () => props.chat.id,
  () => {
    turns.value = [];
    question.value = '';
  }
);

const ask = async text => {
  const content = (text ?? question.value).trim();
  if (!content || isAsking.value) return;
  const history = turns.value.slice();
  turns.value.push({ role: 'user', content });
  question.value = '';
  error.value = '';
  isAsking.value = true;
  scrollToEnd();
  try {
    const { data } = await crmAPI.askCopilot(accountId.value, props.chat.id, {
      question: content,
      history,
    });
    turns.value.push({ role: 'assistant', content: data.answer });
  } catch (requestError) {
    turns.value.pop();
    question.value = content;
    error.value =
      requestError.response?.data?.error || t('ATTENDANCE.COPILOT.ERROR');
  } finally {
    isAsking.value = false;
    scrollToEnd();
  }
};

const useAnswer = content => {
  emitter.emit(
    richEditor.value
      ? BUS_EVENTS.INSERT_INTO_RICH_EDITOR
      : BUS_EVENTS.INSERT_INTO_NORMAL_EDITOR,
    content
  );
  show.value = false;
};

const onKeydown = event => {
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault();
    ask();
  }
};
</script>

<template>
  <Button
    v-tooltip.bottom="$t('ATTENDANCE.COPILOT.TOOLTIP')"
    icon="i-lucide-sparkles"
    size="sm"
    variant="ghost"
    color="slate"
    @click="open"
  />
  <woot-modal v-model:show="show" :on-close="() => (show = false)">
    <div class="crm-modal-form">
      <woot-modal-header
        :header-title="$t('ATTENDANCE.COPILOT.TITLE')"
        :header-content="$t('ATTENDANCE.COPILOT.DESCRIPTION')"
      />

      <div
        ref="listRef"
        class="flex flex-col gap-3 overflow-y-auto max-h-[50vh] min-h-[8rem]"
      >
        <div v-if="!turns.length" class="flex flex-wrap gap-2">
          <button
            v-for="suggestion in suggestions"
            :key="suggestion"
            type="button"
            class="px-3 py-1.5 text-xs font-medium text-left rounded-md border border-n-weak text-n-slate-11 hover:bg-n-alpha-2 transition-colors"
            @click="ask(suggestion)"
          >
            {{ suggestion }}
          </button>
        </div>
        <div
          v-for="(turn, index) in turns"
          :key="index"
          class="flex flex-col gap-2 max-w-[85%] px-3 py-2 text-sm rounded-lg whitespace-pre-wrap break-words"
          :class="
            turn.role === 'user'
              ? 'self-end bg-n-brand/15 text-n-slate-12'
              : 'self-start bg-n-alpha-2 text-n-slate-12'
          "
        >
          <span>{{ turn.content }}</span>
          <Button
            v-if="turn.role === 'assistant'"
            type="button"
            size="xs"
            variant="ghost"
            color="blue"
            icon="i-lucide-corner-down-left"
            class="self-start"
            :label="$t('ATTENDANCE.COPILOT.USE')"
            @click="useAnswer(turn.content)"
          />
        </div>
        <div
          v-if="isAsking"
          class="self-start px-3 py-2 text-sm rounded-lg bg-n-alpha-2 text-n-slate-11 animate-pulse"
        >
          {{ $t('ATTENDANCE.COPILOT.THINKING') }}
        </div>
      </div>

      <p v-if="error" class="mb-0 text-sm text-n-ruby-11">{{ error }}</p>

      <form class="flex items-end w-full gap-2" @submit.prevent="ask()">
        <textarea
          ref="inputRef"
          v-model="question"
          rows="2"
          maxlength="2000"
          class="!mb-0 flex-1 w-full min-w-0"
          :placeholder="$t('ATTENDANCE.COPILOT.PLACEHOLDER')"
          @keydown="onKeydown"
        />
        <Button
          type="submit"
          icon="i-lucide-send-horizontal"
          :is-loading="isAsking"
          :disabled="!question.trim()"
          :label="$t('ATTENDANCE.COPILOT.ASK')"
        />
      </form>
    </div>
  </woot-modal>
</template>
