<script setup>
import '@chatwoot/ninja-keys';
import { ref, computed, watchEffect, onMounted } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useTrack } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useLocale } from 'shared/composables/useLocale';
import { useAppearanceHotKeys } from 'dashboard/composables/commands/useAppearanceHotKeys';
import { useInboxHotKeys } from 'dashboard/composables/commands/useInboxHotKeys';
import { useGoToCommandHotKeys } from 'dashboard/composables/commands/useGoToCommandHotKeys';
import { useBulkActionsHotKeys } from 'dashboard/composables/commands/useBulkActionsHotKeys';
import { useConversationHotKeys } from 'dashboard/composables/commands/useConversationHotKeys';
import wootConstants from 'dashboard/constants/globals';
import {
  GENERAL_EVENTS,
  SNOOZE_EVENTS,
} from 'dashboard/helper/AnalyticsHelper/events';
import { generateSnoozeSuggestions } from 'dashboard/helper/snoozeHelpers';
import { ICON_SNOOZE_CONVERSATION } from 'dashboard/helper/commandbar/icons';
import {
  CMD_SNOOZE_CONVERSATION,
  CMD_SNOOZE_NOTIFICATION,
  CMD_BULK_ACTION_SNOOZE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';
import { emitter } from 'shared/helpers/mitt';

const store = useStore();
const { t, tm } = useI18n();
const { resolvedLocale } = useLocale();

const ninjakeys = ref(null);

// Added selectedSnoozeType to track the selected snooze type
// So if the selected snooze type is "custom snooze" then we set selectedSnoozeType with the CMD action id
// So that we can track the selected snooze type and when we close the command bar
const selectedSnoozeType = ref(null);

const { goToAppearanceHotKeys } = useAppearanceHotKeys();
const { inboxHotKeys } = useInboxHotKeys();
const { goToCommandHotKeys } = useGoToCommandHotKeys();
const { bulkActionsHotKeys } = useBulkActionsHotKeys();
const { conversationHotKeys } = useConversationHotKeys();

const SNOOZE_PARENT_IDS = [
  'snooze_conversation',
  'snooze_notification',
  'bulk_action_snooze_conversation',
];
const DYNAMIC_SNOOZE_PREFIX = 'dynamic_snooze_';

const CUSTOM_SNOOZE = wootConstants.SNOOZE_OPTIONS.UNTIL_CUSTOM_TIME;

const dynamicSnoozeActions = ref([]);
const currentCommandRoot = ref(null);

// Footer of the command bar, in the user's language.
const footerHints = computed(() => [
  { keys: ['↵'], label: t('COMMAND_BAR.FOOTER.SELECT') },
  { keys: ['↑', '↓'], label: t('COMMAND_BAR.FOOTER.NAVIGATE') },
  { keys: ['esc'], label: t('COMMAND_BAR.FOOTER.CLOSE') },
  { keys: ['⌫'], label: t('COMMAND_BAR.FOOTER.BACK') },
]);

const placeholder = computed(() =>
  SNOOZE_PARENT_IDS.includes(currentCommandRoot.value)
    ? t('COMMAND_BAR.SNOOZE_PLACEHOLDER')
    : t('COMMAND_BAR.SEARCH_PLACEHOLDER')
);

const SNOOZE_PRESET_IDS = new Set(Object.values(wootConstants.SNOOZE_OPTIONS));

const hotKeys = computed(() => {
  const allActions = [
    ...dynamicSnoozeActions.value,
    ...inboxHotKeys.value,
    ...goToCommandHotKeys.value,
    ...goToAppearanceHotKeys.value,
    ...bulkActionsHotKeys.value,
    ...conversationHotKeys.value,
  ];
  // When dynamic NLP snooze suggestions exist, hide all preset snooze actions to avoid duplication
  if (!dynamicSnoozeActions.value.length) return allActions;
  return allActions.filter(
    a => !SNOOZE_PRESET_IDS.has(a.id) || !SNOOZE_PARENT_IDS.includes(a.parent)
  );
});

const setCommandBarData = () => {
  ninjakeys.value.data = hotKeys.value;
};

const SNOOZE_EVENT_MAP = {
  snooze_conversation: CMD_SNOOZE_CONVERSATION,
  snooze_notification: CMD_SNOOZE_NOTIFICATION,
  bulk_action_snooze_conversation: CMD_BULK_ACTION_SNOOZE_CONVERSATION,
};

const SNOOZE_SECTION_MAP = {
  snooze_conversation: 'COMMAND_BAR.SECTIONS.SNOOZE_CONVERSATION',
  snooze_notification: 'COMMAND_BAR.SECTIONS.SNOOZE_NOTIFICATION',
  bulk_action_snooze_conversation: 'COMMAND_BAR.SECTIONS.BULK_ACTIONS',
};

const snoozeTranslations = computed(() => {
  const raw = tm('SNOOZE_PARSER');
  if (!raw || typeof raw !== 'object') return {};
  return JSON.parse(JSON.stringify(raw));
});

const buildDynamicSnoozeActions = (search, parentId) => {
  const suggestions = generateSnoozeSuggestions(search, new Date(), {
    translations: snoozeTranslations.value,
    locale: resolvedLocale.value,
  });
  if (!suggestions.length) return [];

  const busEvent = SNOOZE_EVENT_MAP[parentId];
  const section = t(SNOOZE_SECTION_MAP[parentId]);

  return suggestions.map((parsed, index) => ({
    id: `${DYNAMIC_SNOOZE_PREFIX}${index}`,
    title:
      parsed.label !== parsed.formattedDate
        ? `${parsed.label} - ${parsed.formattedDate}`
        : parsed.formattedDate,
    parent: parentId,
    section,
    icon: ICON_SNOOZE_CONVERSATION,
    keywords: search,
    handler: () => {
      emitter.emit(busEvent, parsed.resolve());
      useTrack(SNOOZE_EVENTS.NLP_SNOOZE_APPLIED, { label: parsed.label });
    },
  }));
};

const resetSnoozeState = () => {
  currentCommandRoot.value = null;
  dynamicSnoozeActions.value = [];
};

const patchNinjaKeysOpenClose = el => {
  if (!el || typeof el.open !== 'function' || typeof el.close !== 'function') {
    return;
  }

  const originalOpen = el.open.bind(el);
  const originalClose = el.close.bind(el);

  el.open = (...args) => {
    const [options = {}] = args;
    currentCommandRoot.value = options.parent || null;
    dynamicSnoozeActions.value = [];
    return originalOpen(...args);
  };

  el.close = (...args) => {
    resetSnoozeState();
    return originalClose(...args);
  };
};

const onSelected = item => {
  const {
    detail: {
      action: { title = null, section = null, id = null, children = null } = {},
    } = {},
  } = item;

  selectedSnoozeType.value = id === CUSTOM_SNOOZE ? id : null;

  if (Array.isArray(children) && children.length) {
    currentCommandRoot.value = id;
  }

  useTrack(GENERAL_EVENTS.COMMAND_BAR, { section, action: title });
  setCommandBarData();
};

const onCommandBarChange = item => {
  const { detail: { search = '', actions = [] } = {} } = item;
  const normalizedSearch = search.trim();

  if (actions.length > 0) {
    const uniqueParents = [
      ...new Set(actions.map(action => action.parent).filter(Boolean)),
    ];
    if (uniqueParents.length === 1) {
      currentCommandRoot.value = uniqueParents[0];
    } else {
      currentCommandRoot.value = null;
    }
  }

  if (
    !normalizedSearch ||
    !SNOOZE_PARENT_IDS.includes(currentCommandRoot.value || '')
  ) {
    dynamicSnoozeActions.value = [];
    return;
  }

  dynamicSnoozeActions.value = buildDynamicSnoozeActions(
    normalizedSearch,
    currentCommandRoot.value
  );
};

const onClosed = () => {
  if (selectedSnoozeType.value !== CUSTOM_SNOOZE) {
    store.dispatch('setContextMenuChatId', null);
  }
  resetSnoozeState();
};

watchEffect(() => {
  if (ninjakeys.value) {
    ninjakeys.value.data = hotKeys.value;
  }
});

onMounted(() => {
  setCommandBarData();
  patchNinjaKeysOpenClose(ninjakeys.value);
});
</script>

<!-- eslint-disable vue/attribute-hyphenation -->
<template>
  <ninja-keys
    ref="ninjakeys"
    noAutoLoadMdIcons
    hideBreadcrumbs
    :placeholder="placeholder"
    @change="onCommandBarChange"
    @selected="onSelected"
    @closed="onClosed"
  >
    <!-- eslint-disable-next-line vue/no-deprecated-slot-attribute -- native web component slot -->
    <div slot="footer" class="alvo-cmd-footer">
      <span v-for="hint in footerHints" :key="hint.label">
        <kbd v-for="key in hint.keys" :key="key">{{ key }}</kbd>
        {{ hint.label }}
      </span>
    </div>
  </ninja-keys>
</template>

<style lang="scss">
ninja-keys {
  --ninja-accent-color: #2370ff;
  --ninja-font-family: 'Inter';
  --ninja-key-border-radius: 6px;
  --ninja-backdrop-filter: blur(6px);
  z-index: 9999;
}

// Wrapped with body.dark to avoid overriding the default theme
// If OS is in dark theme and app is in light mode, It will prevent showing dark theme in command bar
body.dark {
  // AlvoChat: the same near-black, thin borders and blue selection as the app.
  ninja-keys {
    --ninja-overflow-background: rgba(0, 0, 0, 0.6);
    --ninja-modal-background: #0e0e10;
    --ninja-modal-shadow: 0 24px 64px rgba(0, 0, 0, 0.6);
    --ninja-separate-border: 1px solid rgba(255, 255, 255, 0.08);
    --ninja-secondary-background-color: #1a1a1f;
    --ninja-selected-background: rgba(35, 112, 255, 0.15);
    --ninja-selected-text-color: #ffffff;
    --ninja-footer-background: #0a0a0b;
    --ninja-text-color: #f4f4f5;
    --ninja-icon-color: #a1a1aa;
    --ninja-secondary-text-color: #a1a1aa;
    --ninja-group-text-color: #71717a;
    --ninja-placeholder-color: #71717a;
  }
}

.alvo-cmd-footer {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
  padding: 0.625rem 1rem;
  font-size: 0.75rem;
  color: var(--ninja-secondary-text-color, #71717a);

  span {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
  }

  kbd {
    min-width: 1.25rem;
    padding: 0.0625rem 0.3125rem;
    border-radius: 4px;
    font-family: inherit;
    font-size: 0.6875rem;
    text-align: center;
    background: var(--ninja-secondary-background-color, #eee);
    color: var(--ninja-text-color, inherit);
  }
}
</style>
