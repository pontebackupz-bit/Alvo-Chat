// Native chatbot flows run by OmnichannelCrm::WorkflowRunner.
//
// Nodes are `{ id, type, position: { x, y }, data }` and connections
// `{ id, source, sourceHandle, target }`. Keep the block types and data keys
// in sync with the runner.

const TINTS = {
  teal: { tint: 'bg-n-teal-3 text-n-teal-11', dot: 'bg-n-teal-9' },
  blue: { tint: 'bg-n-blue-3 text-n-blue-11', dot: 'bg-n-blue-9' },
  iris: { tint: 'bg-n-iris-3 text-n-iris-11', dot: 'bg-n-iris-9' },
  amber: { tint: 'bg-n-amber-3 text-n-amber-11', dot: 'bg-n-amber-9' },
  ruby: { tint: 'bg-n-ruby-3 text-n-ruby-11', dot: 'bg-n-ruby-9' },
  slate: { tint: 'bg-n-alpha-2 text-n-slate-11', dot: 'bg-n-slate-9' },
};

const uid = () =>
  window.crypto?.randomUUID?.() ||
  `${Date.now().toString(16)}-${Math.random().toString(16).slice(2)}`;

export const START = {
  type: 'start',
  icon: 'i-lucide-zap',
  color: 'teal',
  data: () => ({}),
};

// Blocks offered in the palette, in display order.
export const BLOCKS = [
  {
    type: 'send_message',
    icon: 'i-lucide-message-square-text',
    color: 'blue',
    data: () => ({ content: '' }),
  },
  {
    type: 'ask_question',
    icon: 'i-lucide-message-circle-question',
    color: 'iris',
    data: () => ({ content: '', variable: '' }),
  },
  {
    type: 'menu',
    icon: 'i-lucide-list-ordered',
    color: 'iris',
    data: () => ({
      content: '',
      options: [
        { id: uid(), label: '' },
        { id: uid(), label: '' },
      ],
    }),
  },
  {
    type: 'condition',
    icon: 'i-lucide-split',
    color: 'amber',
    data: () => ({ variable: 'resposta', operator: 'contains', value: '' }),
  },
  {
    type: 'wait',
    icon: 'i-lucide-hourglass',
    color: 'amber',
    data: () => ({ minutes: 5 }),
  },
  {
    type: 'add_label',
    icon: 'i-lucide-tag',
    color: 'teal',
    data: () => ({ labels: [] }),
  },
  {
    type: 'transfer_team',
    icon: 'i-lucide-users-round',
    color: 'teal',
    data: () => ({ team_id: null }),
  },
  {
    type: 'assign_agent',
    icon: 'i-lucide-user-round-check',
    color: 'teal',
    data: () => ({ agent_id: null }),
  },
  {
    type: 'end',
    icon: 'i-lucide-flag',
    color: 'ruby',
    data: () => ({ resolve: false }),
  },
];

const BLOCKS_BY_TYPE = Object.fromEntries(
  [START, ...BLOCKS].map(block => [block.type, block])
);

export const CONDITION_OPERATORS = ['contains', 'equals', 'not_empty', 'empty'];
export const CONTACT_VARIABLES = [
  'contato.nome',
  'contato.telefone',
  'contato.email',
];

export const isKnownType = type => Boolean(BLOCKS_BY_TYPE[type]);

export const appearance = type => {
  const block = BLOCKS_BY_TYPE[type];
  return {
    icon: block?.icon || 'i-lucide-circle-help',
    ...TINTS[block?.color || 'slate'],
  };
};

export const newOption = () => ({ id: uid(), label: '' });

export const buildNode = (type, position) => ({
  id: uid(),
  type,
  position,
  data: BLOCKS_BY_TYPE[type].data(),
});

// Outputs as `{ key, labelKey, label, tone }`; `labelKey` is an i18n key
// under CRM.WORKFLOWS.EDITOR.OUTPUTS, `label` free text (menu options).
export const outputsFor = (node, connections) => {
  switch (node.type) {
    case 'end':
      return [];
    case 'start':
      return [{ key: 'next', labelKey: 'NEW_CONVERSATION' }];
    case 'ask_question':
      return [{ key: 'next', labelKey: 'ANSWERED' }];
    case 'condition':
      return [
        { key: 'true', labelKey: 'TRUE', tone: 'green' },
        { key: 'false', labelKey: 'FALSE', tone: 'red' },
      ];
    case 'menu':
      return [
        ...(node.data.options || []).map((option, index) => ({
          key: `option:${option.id}`,
          label: option.label || `${index + 1}`,
        })),
        { key: 'other', labelKey: 'OTHER', tone: 'amber' },
      ];
    default:
      if (isKnownType(node.type)) return [{ key: 'next' }];
      // Imported blocks keep whatever outputs their connections use.
      return [
        ...new Set(
          connections
            .filter(connection => connection.source === node.id)
            .map(connection => connection.sourceHandle || 'next')
        ),
      ].map(key => ({ key, label: key === 'next' ? '' : key }));
  }
};

// Problems that stop a flow from being activated, as `{ nodeId, key }` with
// keys under CRM.WORKFLOWS.EDITOR.PROBLEMS.
export const validateFlow = nodes =>
  nodes.flatMap(node => {
    const { data = {} } = node;
    const problem = key => [{ nodeId: node.id, key }];
    if (!isKnownType(node.type)) return problem('UNSUPPORTED');
    if (
      ['send_message', 'ask_question'].includes(node.type) &&
      !data.content?.trim()
    ) {
      return problem('MISSING_CONTENT');
    }
    if (
      node.type === 'menu' &&
      !(data.options || []).some(option => option.label?.trim())
    ) {
      return problem('MISSING_OPTIONS');
    }
    if (node.type === 'add_label' && !data.labels?.length) {
      return problem('MISSING_LABELS');
    }
    if (node.type === 'transfer_team' && !data.team_id) {
      return problem('MISSING_TEAM');
    }
    if (node.type === 'assign_agent' && !data.agent_id) {
      return problem('MISSING_AGENT');
    }
    return [];
  });

// A new flow greets the contact and ends, so it can be activated right away.
export const starterFlow = greeting => {
  const start = buildNode('start', { x: 0, y: 0 });
  const message = buildNode('send_message', { x: 360, y: 0 });
  message.data.content = greeting;
  const end = buildNode('end', { x: 720, y: 0 });
  return {
    nodes: [start, message, end],
    connections: [
      { id: uid(), source: start.id, sourceHandle: 'next', target: message.id },
      { id: uid(), source: message.id, sourceHandle: 'next', target: end.id },
    ],
  };
};

export const connectionId = uid;
