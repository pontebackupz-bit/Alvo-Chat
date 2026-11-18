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
    type: 'branch',
    icon: 'i-lucide-git-branch',
    color: 'amber',
    data: () => ({
      rules: [{ id: uid(), left: '{{resposta}}', operator: 'eq', right: '' }],
    }),
  },
  {
    type: 'set_variables',
    icon: 'i-lucide-variable',
    color: 'slate',
    data: () => ({ scope: 'flow', values: { '': '' } }),
  },
  {
    type: 'split',
    icon: 'i-lucide-shuffle',
    color: 'amber',
    data: () => ({
      splits: [
        { id: 'a', value: 50 },
        { id: 'b', value: 50 },
      ],
    }),
  },
  {
    type: 'wait',
    icon: 'i-lucide-hourglass',
    color: 'amber',
    data: () => ({ minutes: 5 }),
  },
  {
    type: 'inactivity',
    icon: 'i-lucide-alarm-clock',
    color: 'amber',
    data: () => ({ minutes: 60 }),
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
    data: () => ({ team_id: null, distribute: true }),
  },
  {
    type: 'assign_agent',
    icon: 'i-lucide-user-round-check',
    color: 'teal',
    data: () => ({ agent_id: null }),
  },
  {
    type: 'subflow',
    icon: 'i-lucide-workflow',
    color: 'blue',
    data: () => ({ flow_name: '', data: '', returns: true }),
  },
  {
    type: 'end',
    icon: 'i-lucide-flag',
    color: 'ruby',
    data: () => ({ resolve: false }),
  },
];

// Blocks that only come from imported flows; they are not in the palette.
const IMPORTED_BLOCKS = [
  { type: 'code', icon: 'i-lucide-code', color: 'slate', data: () => ({}) },
  {
    type: 'integration',
    icon: 'i-lucide-database',
    color: 'slate',
    data: () => ({}),
  },
  {
    type: 'note',
    icon: 'i-lucide-sticky-note',
    color: 'amber',
    data: () => ({ text: '' }),
  },
];

const BLOCKS_BY_TYPE = Object.fromEntries(
  [START, ...BLOCKS, ...IMPORTED_BLOCKS].map(block => [block.type, block])
);

export const CONDITION_OPERATORS = ['contains', 'equals', 'not_empty', 'empty'];
export const RULE_OPERATORS = [
  'eq',
  'neq',
  'contains',
  'notContains',
  'startsWith',
  'gt',
  'gte',
  'lt',
  'lte',
  'exists',
  'empty',
];
// Operators that do not compare with a value.
export const UNARY_OPERATORS = ['exists', 'empty'];
export const QUESTION_VALIDATORS = ['', 'cpf_cnpj', 'number', 'email'];
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
export const newRule = () => ({
  id: uid(),
  left: '{{resposta}}',
  operator: 'eq',
  right: '',
});

const SYMBOLS = {
  eq: '=',
  neq: '≠',
  gt: '>',
  gte: '≥',
  lt: '<',
  lte: '≤',
};

// `{{flow.setor}} = comercial` style text for a branch rule.
export const ruleText = rule => {
  const left = (rule.left || '').replace(/^\{\{\s*|\s*\}\}$/g, '');
  const operator = SYMBOLS[rule.operator] || rule.operator;
  return UNARY_OPERATORS.includes(rule.operator)
    ? `${left} ${operator}`
    : `${left} ${operator} ${rule.right || ''}`.trim();
};

const success = { key: 'success', labelKey: 'SUCCESS', tone: 'green' };
const failure = { key: 'error', labelKey: 'ERROR', tone: 'red' };

export const buildNode = (type, position) => ({
  id: uid(),
  type,
  position,
  data: BLOCKS_BY_TYPE[type].data(),
});

// Outputs as `{ key, labelKey, label, tone }`; `labelKey` is an i18n key
// under CRM.WORKFLOWS.EDITOR.OUTPUTS, `label` free text (menu options).
export const outputsFor = (node, connections) => {
  const { data = {} } = node;
  switch (node.type) {
    case 'end':
    case 'note':
      return [];
    case 'start':
      return [{ key: 'next', labelKey: 'NEW_CONVERSATION' }];
    case 'ask_question':
      return [
        { key: 'next', labelKey: 'ANSWERED' },
        ...(data.validator
          ? [{ key: 'max_retries', labelKey: 'MAX_RETRIES', tone: 'red' }]
          : []),
      ];
    case 'branch':
      return [
        ...(data.rules || []).map(rule => ({
          key: String(rule.id),
          label: rule.label || ruleText(rule),
        })),
        { key: 'else', labelKey: 'ELSE', tone: 'amber' },
      ];
    case 'split':
      return (data.splits || []).map(split => ({
        key: String(split.id),
        label: `${String(split.id).toUpperCase()} · ${split.value}%`,
      }));
    case 'inactivity':
      return [
        { key: 'next' },
        { key: 'inactivity', labelKey: 'INACTIVITY', tone: 'amber' },
      ];
    case 'transfer_team':
      return [{ key: 'next' }, failure];
    case 'subflow':
    case 'code':
    case 'integration':
      return [success, failure];
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
      !data.content?.trim() &&
      !data.attachments?.length
    ) {
      return problem('MISSING_CONTENT');
    }
    if (node.type === 'branch' && !data.rules?.length) {
      return problem('MISSING_RULES');
    }
    if (node.type === 'subflow' && !data.flow_name?.trim()) {
      return problem('MISSING_SUBFLOW');
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
    if (node.type === 'transfer_team' && !data.team_id && !data.team_name) {
      return problem('MISSING_TEAM');
    }
    if (node.type === 'assign_agent' && !data.agent_id && !data.agent_email) {
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
