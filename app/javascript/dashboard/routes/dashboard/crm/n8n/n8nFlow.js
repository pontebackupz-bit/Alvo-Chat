// Converts n8n workflows to the editor graph and back.
//
// n8n keys connections by node *name*; the editor keys them by node id so a
// rename never breaks links. Positions are spread out because the board's
// cards are wider than n8n's square nodes.

const SPREAD_X = 1.4;
const SPREAD_Y = 1.25;

const CATEGORY_STYLES = {
  trigger: { tint: 'bg-n-teal-3 text-n-teal-11', dot: 'bg-n-teal-9' },
  logic: { tint: 'bg-n-amber-3 text-n-amber-11', dot: 'bg-n-amber-9' },
  data: { tint: 'bg-n-iris-3 text-n-iris-11', dot: 'bg-n-iris-9' },
  action: { tint: 'bg-n-blue-3 text-n-blue-11', dot: 'bg-n-blue-9' },
  other: { tint: 'bg-n-alpha-2 text-n-slate-11', dot: 'bg-n-slate-9' },
};

const uuid = () =>
  window.crypto?.randomUUID?.() ||
  `${Date.now().toString(16)}-${Math.random().toString(16).slice(2)}`;

// Blocks offered in the palette. `labelKey`/`descriptionKey` are i18n keys
// under CRM.N8N.FLOW.BLOCKS; `outputs` names each main output.
export const NODE_CATALOG = [
  {
    key: 'webhook',
    type: 'n8n-nodes-base.webhook',
    typeVersion: 2,
    category: 'trigger',
    icon: 'i-lucide-webhook',
    trigger: true,
    parameters: () => ({ httpMethod: 'POST', path: uuid(), options: {} }),
    withWebhookId: true,
  },
  {
    key: 'manualTrigger',
    type: 'n8n-nodes-base.manualTrigger',
    typeVersion: 1,
    category: 'trigger',
    icon: 'i-lucide-mouse-pointer-click',
    trigger: true,
    parameters: () => ({}),
  },
  {
    key: 'scheduleTrigger',
    type: 'n8n-nodes-base.scheduleTrigger',
    typeVersion: 1.2,
    category: 'trigger',
    icon: 'i-lucide-clock',
    trigger: true,
    parameters: () => ({ rule: { interval: [{}] } }),
  },
  {
    key: 'if',
    type: 'n8n-nodes-base.if',
    typeVersion: 2,
    category: 'logic',
    icon: 'i-lucide-split',
    outputs: ['TRUE', 'FALSE'],
    parameters: () => ({
      conditions: {
        options: {
          caseSensitive: true,
          leftValue: '',
          typeValidation: 'strict',
        },
        conditions: [],
        combinator: 'and',
      },
      options: {},
    }),
  },
  {
    key: 'wait',
    type: 'n8n-nodes-base.wait',
    typeVersion: 1.1,
    category: 'logic',
    icon: 'i-lucide-hourglass',
    parameters: () => ({}),
    withWebhookId: true,
  },
  {
    key: 'set',
    type: 'n8n-nodes-base.set',
    typeVersion: 3.4,
    category: 'data',
    icon: 'i-lucide-pen-line',
    parameters: () => ({ assignments: { assignments: [] }, options: {} }),
  },
  {
    key: 'code',
    type: 'n8n-nodes-base.code',
    typeVersion: 2,
    category: 'data',
    icon: 'i-lucide-code',
    parameters: () => ({ jsCode: 'return $input.all();' }),
  },
  {
    key: 'httpRequest',
    type: 'n8n-nodes-base.httpRequest',
    typeVersion: 4.2,
    category: 'action',
    icon: 'i-lucide-globe',
    parameters: () => ({ url: '', options: {} }),
  },
  {
    key: 'respondToWebhook',
    type: 'n8n-nodes-base.respondToWebhook',
    typeVersion: 1.1,
    category: 'action',
    icon: 'i-lucide-reply',
    parameters: () => ({ options: {} }),
  },
];

const catalogByType = Object.fromEntries(
  NODE_CATALOG.map(block => [block.type, block])
);

export const isTriggerType = type =>
  Boolean(catalogByType[type]?.trigger) || /trigger$/i.test(type || '');

// Short readable name for node types the palette does not know,
// e.g. "@n8n/n8n-nodes-langchain.agent" -> "agent".
export const shortTypeName = type =>
  (type || '')
    .split('.')
    .pop()
    .replace(/Trigger$/, '');

export const nodeAppearance = type => {
  const block = catalogByType[type];
  const category =
    block?.category || (isTriggerType(type) ? 'trigger' : 'other');
  return {
    blockKey: block?.key,
    icon:
      block?.icon || (category === 'trigger' ? 'i-lucide-zap' : 'i-lucide-box'),
    category,
    ...CATEGORY_STYLES[category],
  };
};

export const outputLabels = (node, edges) => {
  const known = catalogByType[node.type]?.outputs || [];
  const usedIndexes = edges
    .filter(edge => edge.source === node.id && edge.type === 'main')
    .map(edge => edge.output);
  const count = Math.max(known.length, 1, ...usedIndexes.map(i => i + 1));
  return Array.from({ length: count }, (_, index) => known[index] || null);
};

export const uniqueNodeName = (baseName, nodes, ignoreId = null) => {
  const taken = new Set(
    nodes.filter(node => node.id !== ignoreId).map(node => node.name)
  );
  if (!taken.has(baseName)) return baseName;
  let suffix = 1;
  while (taken.has(`${baseName}${suffix}`)) suffix += 1;
  return `${baseName}${suffix}`;
};

export const buildNode = (block, name, position) => ({
  id: uuid(),
  name,
  type: block.type,
  typeVersion: block.typeVersion,
  position,
  parameters: block.parameters(),
  ...(block.withWebhookId ? { webhookId: uuid() } : {}),
});

export const workflowToGraph = workflow => {
  const nodes = (workflow.nodes || []).map(node => ({
    ...node,
    id: node.id || uuid(),
    position: {
      x: (node.position?.[0] || 0) * SPREAD_X,
      y: (node.position?.[1] || 0) * SPREAD_Y,
    },
  }));
  const idByName = Object.fromEntries(nodes.map(node => [node.name, node.id]));
  const edges = [];

  Object.entries(workflow.connections || {}).forEach(([sourceName, types]) => {
    Object.entries(types || {}).forEach(([type, outputs]) => {
      (outputs || []).forEach((targets, output) => {
        (targets || []).forEach(target => {
          const source = idByName[sourceName];
          const targetId = idByName[target.node];
          if (!source || !targetId) return;
          edges.push({
            id: uuid(),
            source,
            output,
            target: targetId,
            input: target.index || 0,
            type,
          });
        });
      });
    });
  });

  return { nodes, edges };
};

export const graphToWorkflow = ({ nodes, edges }) => {
  const nameById = Object.fromEntries(nodes.map(node => [node.id, node.name]));
  const connections = {};

  edges.forEach(edge => {
    const sourceName = nameById[edge.source];
    connections[sourceName] ||= {};
    connections[sourceName][edge.type] ||= [];
    const outputs = connections[sourceName][edge.type];
    while (outputs.length <= edge.output) outputs.push([]);
    outputs[edge.output].push({
      node: nameById[edge.target],
      type: edge.type,
      index: edge.input,
    });
  });

  return {
    nodes: nodes.map(node => ({
      ...node,
      position: [
        Math.round(node.position.x / SPREAD_X),
        Math.round(node.position.y / SPREAD_Y),
      ],
    })),
    connections,
  };
};
