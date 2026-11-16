<script setup>
import { computed, ref } from 'vue';
import { useEventListener } from '@vueuse/core';
import Button from 'dashboard/components-next/button/Button.vue';

// Pannable, zoomable board shared by the flow editors.
//
// Nodes need `id` and `position: { x, y }`; the board moves them in place.
// `describeNode(node)` returns how a node looks:
//   { icon, tint, dot, category, title, subtitle, disabled,
//     inputs: number, outputs: [{ key, label, tone }] }
// Edges are `{ id, source, sourceHandle, target, targetHandle, vertical }`,
// where `sourceHandle` is an output key and `targetHandle` an input index.
const props = defineProps({
  nodes: { type: Array, required: true },
  edges: { type: Array, required: true },
  describeNode: { type: Function, required: true },
  blocks: { type: Array, required: true },
});

const emit = defineEmits(['addBlock', 'connect', 'deleteSelection', 'moved']);

const selection = defineModel('selection', { type: Object, default: null });

const NODE_WIDTH = 232;
const NODE_HEIGHT = 92;
const MIN_ZOOM = 0.25;
const MAX_ZOOM = 2;
const GRID = 24;
const HANDLE_OFFSET = 6;

const TONES = {
  brand: { handle: 'bg-n-brand', label: 'text-n-slate-11' },
  green: { handle: 'bg-n-teal-9', label: 'text-n-teal-11' },
  red: { handle: 'bg-n-ruby-9', label: 'text-n-ruby-11' },
  amber: { handle: 'bg-n-amber-9', label: 'text-n-amber-11' },
};

const pan = ref({ x: 80, y: 120 });
const zoom = ref(1);
const pendingConnection = ref(null);
const viewport = ref(null);
let interaction = null;

const views = computed(() =>
  Object.fromEntries(
    props.nodes.map(node => [node.id, props.describeNode(node)])
  )
);
const nodesById = computed(() =>
  Object.fromEntries(props.nodes.map(node => [node.id, node]))
);

const zoomLabel = computed(() => `${Math.round(zoom.value * 100)}%`);
const canvasTransform = computed(
  () => `translate(${pan.value.x}px, ${pan.value.y}px) scale(${zoom.value})`
);
const gridTransform = computed(
  () => `translate(${pan.value.x} ${pan.value.y}) scale(${zoom.value})`
);

const toneOf = output => TONES[output?.tone] || TONES.brand;

const handleTop = (index, count) =>
  (NODE_HEIGHT * (index + 1)) / (count + 1) - HANDLE_OFFSET;

const outputPoint = (node, key) => {
  const outputs = views.value[node.id].outputs;
  const index = Math.max(
    0,
    outputs.findIndex(output => output.key === key)
  );
  return {
    x: node.position.x + NODE_WIDTH,
    y: node.position.y + (NODE_HEIGHT * (index + 1)) / (outputs.length + 1),
  };
};

const inputPoint = (node, index) => {
  const count = Math.max(1, views.value[node.id].inputs);
  return {
    x: node.position.x,
    y: node.position.y + (NODE_HEIGHT * (index + 1)) / (count + 1),
  };
};

const curve = (from, to) => {
  const dx = Math.max(60, Math.abs(to.x - from.x) / 2);
  return `M ${from.x} ${from.y} C ${from.x + dx} ${from.y}, ${to.x - dx} ${to.y}, ${to.x} ${to.y}`;
};

// Sub-node links (e.g. n8n AI models) run from the source's top to the
// target's bottom.
const verticalCurve = (from, to) => {
  const dy = Math.max(40, Math.abs(to.y - from.y) / 2);
  return `M ${from.x} ${from.y} C ${from.x} ${from.y - dy}, ${to.x} ${to.y + dy}, ${to.x} ${to.y}`;
};

const renderedEdges = computed(() =>
  props.edges.flatMap(edge => {
    const source = nodesById.value[edge.source];
    const target = nodesById.value[edge.target];
    if (!source || !target) return [];

    if (edge.vertical) {
      const from = {
        x: source.position.x + NODE_WIDTH / 2,
        y: source.position.y,
      };
      const to = {
        x: target.position.x + NODE_WIDTH / 2,
        y: target.position.y + NODE_HEIGHT,
      };
      return [{ ...edge, path: verticalCurve(from, to), dashed: true }];
    }

    const from = outputPoint(source, edge.sourceHandle);
    const to = inputPoint(target, edge.targetHandle || 0);
    const output = views.value[source.id].outputs.find(
      item => item.key === edge.sourceHandle
    );
    return [
      {
        ...edge,
        path: curve(from, to),
        label: views.value[source.id].outputs.length > 1 ? '' : output?.label,
        labelX: from.x + 12,
        labelY: from.y - 8,
      },
    ];
  })
);

const pendingPath = computed(() => {
  if (!pendingConnection.value) return null;
  const { source, sourceHandle, x, y } = pendingConnection.value;
  return curve(outputPoint(nodesById.value[source], sourceHandle), { x, y });
});

const toCanvasPoint = event => {
  const rect = viewport.value.getBoundingClientRect();
  return {
    x: (event.clientX - rect.left - pan.value.x) / zoom.value,
    y: (event.clientY - rect.top - pan.value.y) / zoom.value,
  };
};

const snap = value => Math.round(value / GRID) * GRID;

const fitView = () => {
  const rect = viewport.value?.getBoundingClientRect();
  if (!rect || !props.nodes.length) return;
  const xs = props.nodes.map(node => node.position.x);
  const ys = props.nodes.map(node => node.position.y);
  const minX = Math.min(...xs);
  const minY = Math.min(...ys);
  const width = Math.max(...xs) + NODE_WIDTH - minX;
  const height = Math.max(...ys) + NODE_HEIGHT - minY;
  const padding = 96;
  zoom.value = Math.min(
    1,
    Math.max(
      MIN_ZOOM,
      Math.min(
        (rect.width - padding * 2) / width,
        (rect.height - padding * 2) / height
      )
    )
  );
  pan.value = {
    x: (rect.width - width * zoom.value) / 2 - minX * zoom.value,
    y: (rect.height - height * zoom.value) / 2 - minY * zoom.value,
  };
};

const zoomAround = (factor, center) => {
  const nextZoom = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, zoom.value * factor));
  const ratio = nextZoom / zoom.value;
  pan.value = {
    x: center.x - (center.x - pan.value.x) * ratio,
    y: center.y - (center.y - pan.value.y) * ratio,
  };
  zoom.value = nextZoom;
};

const zoomBy = factor => {
  const rect = viewport.value.getBoundingClientRect();
  zoomAround(factor, { x: rect.width / 2, y: rect.height / 2 });
};

const onWheel = event => {
  if (event.ctrlKey || event.metaKey) {
    const rect = viewport.value.getBoundingClientRect();
    zoomAround(event.deltaY < 0 ? 1.1 : 1 / 1.1, {
      x: event.clientX - rect.left,
      y: event.clientY - rect.top,
    });
    return;
  }
  pan.value = {
    x: pan.value.x - event.deltaX,
    y: pan.value.y - event.deltaY,
  };
};

const select = (kind, id) => {
  selection.value = kind ? { kind, id } : null;
};

const onBackgroundPointerDown = event => {
  if (event.button !== 0) return;
  select(null);
  interaction = {
    mode: 'pan',
    startX: event.clientX,
    startY: event.clientY,
    origin: { ...pan.value },
  };
};

const onNodePointerDown = (event, node) => {
  if (event.button !== 0) return;
  select('node', node.id);
  interaction = {
    mode: 'node',
    node,
    startX: event.clientX,
    startY: event.clientY,
    origin: { ...node.position },
    moved: false,
  };
};

const onOutputPointerDown = (event, node, output) => {
  if (event.button !== 0) return;
  pendingConnection.value = {
    source: node.id,
    sourceHandle: output.key,
    ...toCanvasPoint(event),
  };
  interaction = { mode: 'connect' };
};

useEventListener(window, 'pointermove', event => {
  if (!interaction) return;
  const dx = event.clientX - interaction.startX;
  const dy = event.clientY - interaction.startY;

  if (interaction.mode === 'pan') {
    pan.value = { x: interaction.origin.x + dx, y: interaction.origin.y + dy };
  } else if (interaction.mode === 'node') {
    if (!interaction.moved && Math.hypot(dx, dy) < 3) return;
    interaction.moved = true;
    interaction.node.position = {
      x: snap(interaction.origin.x + dx / zoom.value),
      y: snap(interaction.origin.y + dy / zoom.value),
    };
  } else if (interaction.mode === 'connect') {
    Object.assign(pendingConnection.value, toCanvasPoint(event));
  }
});

useEventListener(window, 'pointerup', event => {
  if (interaction?.mode === 'node' && interaction.moved) emit('moved');
  if (interaction?.mode === 'connect') {
    const targetId = document
      .elementFromPoint(event.clientX, event.clientY)
      ?.closest('[data-flow-node]')?.dataset.flowNode;
    const { source, sourceHandle } = pendingConnection.value;
    const target = nodesById.value[targetId];
    if (target && targetId !== source && views.value[targetId].inputs > 0) {
      emit('connect', { source, sourceHandle, target: targetId });
    }
    pendingConnection.value = null;
  }
  interaction = null;
});

useEventListener(window, 'keydown', event => {
  if (event.target.closest('input, textarea, select, [contenteditable]')) {
    return;
  }
  if (event.key === 'Delete' || event.key === 'Backspace') {
    emit('deleteSelection');
  }
  if (event.key === 'Escape') select(null);
});

const addBlockAtCenter = blockKey => {
  const rect = viewport.value.getBoundingClientRect();
  const offset = (props.nodes.length % 5) * GRID;
  emit('addBlock', blockKey, {
    x: snap(
      (rect.width / 2 - pan.value.x) / zoom.value - NODE_WIDTH / 2 + offset
    ),
    y: snap(
      (rect.height / 2 - pan.value.y) / zoom.value - NODE_HEIGHT / 2 + offset
    ),
  });
};

const onPaletteDragStart = (event, blockKey) => {
  event.dataTransfer.setData('text/plain', blockKey);
  event.dataTransfer.effectAllowed = 'copy';
};

const onCanvasDrop = event => {
  const blockKey = event.dataTransfer.getData('text/plain');
  if (!props.blocks.some(block => block.key === blockKey)) return;
  const point = toCanvasPoint(event);
  emit('addBlock', blockKey, {
    x: snap(point.x - NODE_WIDTH / 2),
    y: snap(point.y - NODE_HEIGHT / 2),
  });
};

defineExpose({ fitView });
</script>

<template>
  <div
    ref="viewport"
    class="relative flex-1 overflow-hidden select-none touch-none bg-n-surface-1"
    :class="pendingConnection ? 'cursor-crosshair' : 'cursor-grab'"
    @pointerdown="onBackgroundPointerDown"
    @wheel.prevent="onWheel"
    @dragover.prevent
    @drop.prevent="onCanvasDrop"
  >
    <svg class="absolute inset-0 pointer-events-none size-full">
      <defs>
        <pattern
          id="flow-canvas-grid"
          :width="GRID"
          :height="GRID"
          patternUnits="userSpaceOnUse"
          :patternTransform="gridTransform"
        >
          <path
            :d="`M ${GRID} 0 L 0 0 0 ${GRID}`"
            fill="none"
            class="stroke-n-weak"
            stroke-width="0.6"
          />
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill="url(#flow-canvas-grid)" />
    </svg>

    <div
      class="absolute top-0 left-0 origin-top-left"
      :style="{ transform: canvasTransform }"
    >
      <svg class="absolute top-0 left-0 overflow-visible size-px">
        <g v-for="edge in renderedEdges" :key="edge.id">
          <path
            :d="edge.path"
            fill="none"
            stroke="transparent"
            stroke-width="14"
            class="cursor-pointer"
            @pointerdown.stop="select('edge', edge.id)"
          />
          <path
            :d="edge.path"
            fill="none"
            stroke-width="2"
            class="pointer-events-none"
            :class="
              selection?.id === edge.id ? 'stroke-n-brand' : 'stroke-n-blue-8'
            "
            :stroke-dasharray="edge.dashed ? '6 4' : null"
          />
          <text
            v-if="edge.label"
            :x="edge.labelX"
            :y="edge.labelY"
            class="text-[10px] fill-n-slate-11 pointer-events-none"
          >
            {{ edge.label }}
          </text>
        </g>
        <path
          v-if="pendingPath"
          :d="pendingPath"
          fill="none"
          stroke-width="2"
          stroke-dasharray="6 4"
          class="pointer-events-none stroke-n-brand"
        />
      </svg>

      <div
        v-for="node in nodes"
        :key="node.id"
        :data-flow-node="node.id"
        class="absolute flex items-start gap-3 p-3 border shadow-sm cursor-pointer rounded-xl bg-n-solid-2 w-[232px] h-[92px]"
        :class="[
          selection?.id === node.id
            ? 'border-n-brand ring-2 ring-n-brand/30'
            : 'border-n-weak hover:border-n-strong',
          pendingConnection &&
          pendingConnection.source !== node.id &&
          views[node.id].inputs > 0
            ? 'ring-2 ring-n-brand/20'
            : '',
          { 'opacity-50': views[node.id].disabled },
        ]"
        :style="{ left: `${node.position.x}px`, top: `${node.position.y}px` }"
        @pointerdown.stop="onNodePointerDown($event, node)"
      >
        <div
          class="flex items-center justify-center flex-shrink-0 rounded-lg size-10"
          :class="views[node.id].tint"
        >
          <span class="size-5" :class="views[node.id].icon" />
        </div>
        <div class="min-w-0">
          <div
            class="flex items-center gap-1.5 text-[10px] font-semibold tracking-wider uppercase text-n-slate-11"
          >
            <span class="rounded-full size-1.5" :class="views[node.id].dot" />
            <span class="truncate">{{ views[node.id].category }}</span>
          </div>
          <div class="text-sm font-semibold truncate text-n-slate-12">
            {{ views[node.id].title }}
          </div>
          <div class="text-xs line-clamp-2 text-n-slate-11">
            {{ views[node.id].subtitle }}
          </div>
        </div>

        <span
          v-for="index in views[node.id].inputs"
          :key="`in-${index}`"
          class="absolute border-2 rounded-full size-3 -left-1.5 bg-n-slate-9 border-n-solid-2"
          :style="{
            top: `${handleTop(index - 1, views[node.id].inputs)}px`,
          }"
        />
        <template
          v-for="(output, index) in views[node.id].outputs"
          :key="output.key"
        >
          <span
            class="absolute border-2 rounded-full cursor-crosshair size-3 -right-1.5 border-n-solid-2 hover:scale-125"
            :class="toneOf(output).handle"
            :style="{
              top: `${handleTop(index, views[node.id].outputs.length)}px`,
            }"
            @pointerdown.stop="onOutputPointerDown($event, node, output)"
          />
          <span
            v-if="output.label && views[node.id].outputs.length > 1"
            class="absolute ml-3 text-[10px] font-medium whitespace-nowrap pointer-events-none left-full"
            :class="toneOf(output).label"
            :style="{
              top: `${handleTop(index, views[node.id].outputs.length) - HANDLE_OFFSET}px`,
            }"
          >
            {{ output.label }}
          </span>
        </template>
      </div>
    </div>

    <aside
      class="absolute flex flex-col gap-1 p-3 overflow-y-auto border shadow-lg cursor-default top-3 left-3 w-60 max-h-[calc(100%-6rem)] rounded-xl border-n-weak bg-n-solid-1"
      @pointerdown.stop
      @wheel.stop
    >
      <h3
        class="px-1 mb-1 text-[10px] font-semibold tracking-widest uppercase text-n-slate-11"
      >
        {{ $t('CRM.FLOW_CANVAS.BLOCKS_TITLE') }}
      </h3>
      <button
        v-for="block in blocks"
        :key="block.key"
        type="button"
        draggable="true"
        class="flex items-center gap-3 p-1.5 text-left rounded-lg hover:bg-n-alpha-1 cursor-grab active:cursor-grabbing"
        @dragstart="onPaletteDragStart($event, block.key)"
        @click="addBlockAtCenter(block.key)"
      >
        <span
          class="flex items-center justify-center flex-shrink-0 rounded-lg size-8"
          :class="block.tint"
        >
          <span class="size-4" :class="block.icon" />
        </span>
        <span class="min-w-0">
          <span class="block text-sm font-semibold truncate text-n-slate-12">
            {{ block.label }}
          </span>
          <span class="block text-xs truncate text-n-slate-11">
            {{ block.description }}
          </span>
        </span>
      </button>
      <p class="px-1 pt-2 text-xs leading-relaxed text-n-slate-11">
        <slot name="paletteHint" />
      </p>
    </aside>

    <div
      class="absolute flex flex-col overflow-hidden border rounded-lg shadow-sm bottom-3 left-3 border-n-weak bg-n-solid-1"
      @pointerdown.stop
    >
      <Button
        icon="i-lucide-plus"
        color="slate"
        variant="ghost"
        size="sm"
        @click="zoomBy(1.2)"
      />
      <Button
        icon="i-lucide-minus"
        color="slate"
        variant="ghost"
        size="sm"
        @click="zoomBy(1 / 1.2)"
      />
      <Button
        icon="i-lucide-maximize"
        color="slate"
        variant="ghost"
        size="sm"
        @click="fitView"
      />
    </div>
    <p
      class="absolute text-xs pointer-events-none bottom-4 left-16 text-n-slate-10"
    >
      {{ $t('CRM.FLOW_CANVAS.HINT', { zoom: zoomLabel }) }}
    </p>
  </div>
</template>
