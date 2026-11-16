<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import AlvoradaWordmark from 'shared/components/AlvoradaWordmark.vue';

const content = {
  company: 'Comercial Alvorada',
  access: 'Entrar no AlvoChat',
  nav: [
    { label: 'Como funciona', href: '#como-funciona' },
    { label: 'Recursos', href: '#recursos' },
    { label: 'Segurança', href: '#seguranca' },
  ],
  badge: 'Novo: chatbot com fluxos visuais no WhatsApp',
  titleStart: 'Toda conversa',
  titleHighlight: 'vira oportunidade.',
  description:
    'O AlvoChat reúne WhatsApp, Instagram, e-mail e o chat do site em uma só caixa, distribui cada atendimento para a pessoa certa e transforma conversas em vendas acompanhadas de perto.',
  secondaryCta: 'Ver como funciona',
  checks: ['Todos os canais em uma caixa', 'Respostas do celular registradas'],
  inboxTitle: 'Caixa de entrada',
  inboxLive: 'ao vivo',
  inboxCaption: 'Exemplo ilustrativo da operação',
  channelsTitle: 'Os canais que seus clientes já usam',
  stepsEyebrow: 'Como funciona',
  stepsTitle: 'Do primeiro "oi" ao pedido fechado',
  stepsDescription:
    'Cada etapa fica registrada, então ninguém precisa perguntar onde a conversa parou.',
  featuresEyebrow: 'Recursos',
  featuresTitle: 'Tudo o que a equipe comercial precisa, num lugar só',
  securityEyebrow: 'Segurança',
  securityTitle: 'Controle de quem vê e faz o quê',
  ctaTitle: 'Sua equipe pronta para a próxima conversa.',
  ctaDescription:
    'Entre com o acesso fornecido pelo administrador da sua operação.',
  footerNote: 'Atendimento, relacionamento e resultado em um só fluxo.',
};

const stats = [
  { value: '1 caixa', label: 'para WhatsApp, e-mail e chat do site' },
  { value: '360°', label: 'de contexto: histórico completo de cada cliente' },
  { value: '100%', label: 'de visibilidade para supervisores' },
  { value: '24h', label: 'chatbot respondendo por você' },
];

const channels = [
  { label: 'WhatsApp', icon: 'i-ri-whatsapp-line' },
  { label: 'Instagram', icon: 'i-ri-instagram-line' },
  { label: 'Messenger', icon: 'i-ri-messenger-line' },
  { label: 'Telegram', icon: 'i-ri-telegram-line' },
  { label: 'E-mail', icon: 'i-lucide-mail' },
  { label: 'Chat do site', icon: 'i-lucide-message-circle' },
];

const conversations = [
  {
    initials: 'MS',
    name: 'Mariana S.',
    message: 'Gostaria de receber uma proposta.',
    channel: 'i-ri-whatsapp-line',
    time: 'agora',
    tone: 'bg-[#3b82f6]/15 text-[#bfdbfe]',
    unread: true,
  },
  {
    initials: 'RB',
    name: 'Rafael B.',
    message: 'Podemos seguir com o pedido?',
    channel: 'i-ri-instagram-line',
    time: '4 min',
    tone: 'bg-[#8b5cf6]/15 text-[#ddd6fe]',
    unread: true,
  },
  {
    initials: 'LC',
    name: 'Loja Central',
    message: 'Você: Segue a tabela atualizada ✅',
    channel: 'i-lucide-mail',
    time: '12 min',
    tone: 'bg-[#10b981]/15 text-[#a7f3d0]',
    unread: false,
  },
];

const liveEvents = [
  {
    icon: 'i-lucide-message-square-plus',
    title: 'Nova conversa no WhatsApp',
    detail: 'Distribuída para Ana · Equipe Vendas',
    tone: 'text-[#93c5fd]',
  },
  {
    icon: 'i-lucide-trending-up',
    title: 'Lead avançou no funil',
    detail: 'Proposta enviada · Rafael B.',
    tone: 'text-[#6ee7b7]',
  },
  {
    icon: 'i-lucide-smartphone',
    title: 'Resposta enviada pelo celular',
    detail: 'Registrada na conversa com Mariana S.',
    tone: 'text-[#fcd34d]',
  },
  {
    icon: 'i-lucide-workflow',
    title: 'Automação n8n executada',
    detail: 'Boas-vindas enviadas ao novo contato',
    tone: 'text-[#c4b5fd]',
  },
];

const steps = [
  {
    icon: 'i-lucide-message-circle',
    title: 'O cliente chama',
    text: 'Pelo canal que preferir. A mensagem chega na mesma caixa de entrada, com o histórico do contato.',
  },
  {
    icon: 'i-lucide-shuffle',
    title: 'A conversa é distribuída',
    text: 'Regras de distribuição enviam o atendimento para a equipe e a pessoa certas, sem fila esquecida.',
  },
  {
    icon: 'i-lucide-headset',
    title: 'A equipe atende',
    text: 'No AlvoChat ou direto no celular: o que for respondido fora do sistema também aparece na conversa.',
  },
  {
    icon: 'i-lucide-workflow',
    title: 'As automações trabalham junto',
    text: 'Fluxos n8n montados no painel visual respondem, avisam e atualizam dados a partir dos eventos do CRM.',
  },
  {
    icon: 'i-lucide-chart-no-axes-combined',
    title: 'Você acompanha o resultado',
    text: 'Leads, conversas e desempenho da equipe no painel, com histórico de tudo o que mudou.',
  },
];

const features = [
  {
    icon: 'i-lucide-inbox',
    title: 'Caixa de entrada omnichannel',
    text: 'WhatsApp com mais de um número, Instagram, e-mail e chat do site lado a lado, com etiquetas, notas e respostas prontas.',
    wide: true,
  },
  {
    icon: 'i-lucide-target',
    title: 'CRM e funil de leads',
    text: 'Cada oportunidade com etapa, responsável e próximo passo.',
  },
  {
    icon: 'i-lucide-shuffle',
    title: 'Distribuição automática',
    text: 'Atendimentos divididos por equipe e regra, sem disputa por conversa.',
  },
  {
    icon: 'i-lucide-workflow',
    title: 'Fluxos visuais com n8n',
    text: 'Arraste blocos, ligue as saídas e salve o fluxo direto no n8n.',
  },
  {
    icon: 'i-lucide-contact',
    title: 'Contatos organizados',
    text: 'Importe e exporte a base em CSV, com filtros, segmentos e etiquetas.',
  },
];

const security = [
  {
    icon: 'i-lucide-shield-check',
    title: 'Papéis e permissões',
    text: 'Administradores, supervisores e agentes veem apenas o que precisam.',
  },
  {
    icon: 'i-lucide-scroll-text',
    title: 'Registro de auditoria',
    text: 'Mudanças importantes ficam registradas com autor e horário.',
  },
  {
    icon: 'i-lucide-key-round',
    title: 'Acesso controlado',
    text: 'Contas e senhas são criadas e redefinidas pelo administrador.',
  },
  {
    icon: 'i-lucide-server',
    title: 'Dados da operação',
    text: 'Conversas e contatos ficam na infraestrutura da Comercial Alvorada.',
  },
];

const card =
  'group relative isolate overflow-hidden rounded-2xl border border-transparent [background:linear-gradient(180deg,rgba(14,22,42,0.92),rgba(7,11,22,0.94))_padding-box,linear-gradient(160deg,rgba(147,197,253,0.32),rgba(255,255,255,0.05)_32%,rgba(255,255,255,0.03)_68%,rgba(59,130,246,0.28))_border-box] shadow-[0_30px_70px_-40px_rgba(0,0,0,0.95),inset_0_1px_0_rgba(255,255,255,0.06)]';
const cardGlow =
  'pointer-events-none absolute inset-0 -z-10 bg-[radial-gradient(420px_circle_at_var(--mx,50%)_var(--my,-20%),rgba(96,165,250,0.14),transparent_60%)] opacity-70 transition-opacity duration-500 group-hover:opacity-100';
const cardShine =
  'pointer-events-none absolute inset-x-[12%] top-0 h-px bg-gradient-to-r from-transparent via-[#bfdbfe]/70 to-transparent';

// Card glow follows the pointer through CSS variables read by `cardGlow`.
const trackPointer = event => {
  const rect = event.currentTarget.getBoundingClientRect();
  event.currentTarget.style.setProperty(
    '--mx',
    `${event.clientX - rect.left}px`
  );
  event.currentTarget.style.setProperty(
    '--my',
    `${event.clientY - rect.top}px`
  );
};

const isScrolled = ref(false);
const now = ref(Date.now());
const notifications = ref([]);
let eventIndex = 0;
let timers = [];

const pushNotification = () => {
  const event = liveEvents[eventIndex % liveEvents.length];
  notifications.value = [
    { ...event, id: eventIndex, at: Date.now() },
    ...notifications.value,
  ].slice(0, 2);
  eventIndex += 1;
};

const relativeTime = at => {
  const seconds = Math.floor((now.value - at) / 1000);
  if (seconds < 5) return 'agora';
  if (seconds < 60) return `há ${seconds} s`;
  return `há ${Math.floor(seconds / 60)} min`;
};

const headerClasses = computed(() =>
  isScrolled.value
    ? 'border-white/10 bg-[#05070d]/80 backdrop-blur-xl'
    : 'border-transparent bg-transparent'
);

const onScroll = () => {
  isScrolled.value = window.scrollY > 16;
};

onMounted(() => {
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });
  pushNotification();
  pushNotification();
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  timers = [
    window.setInterval(pushNotification, 3200),
    window.setInterval(() => {
      now.value = Date.now();
    }, 1000),
  ];
});

onBeforeUnmount(() => {
  window.removeEventListener('scroll', onScroll);
  timers.forEach(timer => window.clearInterval(timer));
});
</script>

<template>
  <div
    class="relative min-h-screen overflow-x-hidden bg-[#05070d] font-inter text-[#f4f7fb] antialiased scroll-smooth"
  >
    <div class="pointer-events-none absolute inset-x-0 top-0 h-[60rem]">
      <div
        class="absolute -left-40 -top-40 size-[42rem] rounded-full bg-[#2a6bff]/25 blur-[120px] motion-safe:animate-glow-drift"
      />
      <div
        class="absolute -right-32 top-48 size-[34rem] rounded-full bg-[#087cff]/15 blur-[120px] motion-safe:animate-glow-drift motion-safe:[animation-delay:-12s]"
      />
      <div
        class="absolute inset-0 bg-[linear-gradient(rgba(255,255,255,0.035)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.035)_1px,transparent_1px)] bg-[size:64px_64px] [mask-image:radial-gradient(ellipse_at_top,black_20%,transparent_70%)]"
      />
    </div>

    <header
      class="sticky top-0 z-30 border-b transition-colors duration-300"
      :class="headerClasses"
    >
      <div
        class="mx-auto flex h-16 max-w-7xl items-center justify-between gap-6 px-6 sm:px-10"
      >
        <a href="/" class="flex items-center" :aria-label="content.company">
          <AlvoradaWordmark tone="light" :subtitle="false" />
        </a>
        <nav class="hidden items-center gap-8 text-sm text-[#929cad] md:flex">
          <a
            v-for="item in content.nav"
            :key="item.href"
            :href="item.href"
            class="transition-colors hover:text-white"
          >
            {{ item.label }}
          </a>
        </nav>
        <a
          href="/app/login"
          class="rounded-[10px] bg-[#087cff] px-4 py-2 text-sm font-semibold text-white shadow-[0_8px_30px_-8px_rgba(8,124,255,0.8)] transition duration-200 hover:bg-[#168cff] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#93c5fd] focus-visible:ring-offset-2 focus-visible:ring-offset-[#05070d]"
        >
          {{ content.access }}
        </a>
      </div>
    </header>

    <main class="relative">
      <section
        class="mx-auto grid max-w-7xl items-center gap-16 px-6 pb-20 pt-16 sm:px-10 lg:grid-cols-[1.05fr_0.95fr] lg:pb-28 lg:pt-24"
      >
        <div class="motion-safe:animate-fade-in-up">
          <a
            href="#recursos"
            class="inline-flex items-center gap-2 rounded-full border border-[#60a5fa]/25 bg-[#3b82f6]/10 px-3.5 py-1.5 text-xs font-medium text-[#bfdbfe] transition hover:border-[#93c5fd]/40"
          >
            <span
              class="size-1.5 rounded-full bg-[#2bd67b] motion-safe:animate-pulse"
            />
            {{ content.badge }}
            <span class="i-lucide-arrow-right size-3.5" />
          </a>
          <h1
            class="relative mt-7 text-5xl font-semibold leading-[1.04] tracking-[-0.035em] sm:text-6xl lg:text-7xl"
          >
            <span
              class="pointer-events-none absolute inset-x-[10%] inset-y-[10%] -z-10 bg-[radial-gradient(closest-side,rgba(59,130,246,0.25),transparent)] blur-2xl"
            />
            {{ content.titleStart }}
            <span
              class="block bg-gradient-to-r from-white via-[#bfdbfe] to-[#3b82f6] bg-clip-text text-transparent"
            >
              {{ content.titleHighlight }}
            </span>
          </h1>
          <p class="mt-7 max-w-xl text-lg leading-8 text-[#929cad]">
            {{ content.description }}
          </p>
          <div class="mt-10 flex flex-wrap items-center gap-4">
            <a
              href="/app/login"
              class="group inline-flex items-center gap-2 rounded-xl bg-[#087cff] px-6 py-3.5 text-base font-semibold text-white shadow-[0_18px_50px_-14px_rgba(8,124,255,0.9)] transition duration-200 hover:-translate-y-0.5 hover:bg-[#168cff] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#93c5fd] focus-visible:ring-offset-2 focus-visible:ring-offset-[#05070d]"
            >
              {{ content.access }}
              <span
                class="i-lucide-arrow-up-right size-5 transition-transform group-hover:-translate-y-0.5 group-hover:translate-x-0.5"
              />
            </a>
            <a
              href="#como-funciona"
              class="inline-flex items-center gap-2 rounded-xl border border-white/10 bg-white/[0.04] px-6 py-3.5 text-base font-medium text-white transition hover:border-white/20 hover:bg-white/[0.08]"
            >
              {{ content.secondaryCta }}
            </a>
          </div>
          <ul
            class="mt-8 flex flex-wrap gap-x-6 gap-y-2 text-sm text-[#929cad]"
          >
            <li
              v-for="check in content.checks"
              :key="check"
              class="inline-flex items-center gap-2"
            >
              <span class="i-lucide-circle-check size-4 text-[#2bd67b]" />
              {{ check }}
            </li>
          </ul>
        </div>

        <div
          class="relative mx-auto w-full max-w-lg motion-safe:animate-fade-in-up"
        >
          <div
            class="absolute -inset-10 -z-10 rounded-[3rem] bg-[#2a6bff]/15 blur-3xl"
          />
          <div :class="card" class="p-5 sm:p-6" @pointermove="trackPointer">
            <div :class="cardGlow" />
            <div :class="cardShine" />
            <div class="flex items-center justify-between gap-4">
              <div class="flex items-center gap-3">
                <span
                  class="flex size-9 items-center justify-center rounded-xl bg-[#087cff]/15 text-[#93c5fd]"
                >
                  <span class="i-lucide-inbox size-5" />
                </span>
                <p class="text-base font-semibold">{{ content.inboxTitle }}</p>
              </div>
              <span
                class="inline-flex items-center gap-1.5 rounded-full bg-[#34d399]/10 px-2.5 py-1 text-xs font-medium text-[#6ee7b7]"
              >
                <span
                  class="size-1.5 rounded-full bg-[#2bd67b] motion-safe:animate-pulse"
                />
                {{ content.inboxLive }}
              </span>
            </div>

            <ul class="mt-5 divide-y divide-white/[0.06]">
              <li
                v-for="conversation in conversations"
                :key="conversation.name"
                class="flex items-center gap-3 py-3.5"
              >
                <span
                  class="relative flex size-10 shrink-0 items-center justify-center rounded-full text-xs font-bold"
                  :class="conversation.tone"
                >
                  {{ conversation.initials }}
                  <span
                    class="absolute -bottom-0.5 -right-0.5 flex size-4 items-center justify-center rounded-full bg-[#0a0e15] text-[#929cad]"
                  >
                    <span class="size-3" :class="conversation.channel" />
                  </span>
                </span>
                <span class="min-w-0 flex-1">
                  <span class="block truncate text-sm font-semibold">
                    {{ conversation.name }}
                  </span>
                  <span class="mt-0.5 block truncate text-xs text-[#929cad]">
                    {{ conversation.message }}
                  </span>
                </span>
                <span class="flex flex-col items-end gap-1.5">
                  <span class="text-xs text-[#566174]">{{
                    conversation.time
                  }}</span>
                  <span
                    v-if="conversation.unread"
                    class="size-2 rounded-full bg-[#087cff]"
                  />
                </span>
              </li>
            </ul>

            <TransitionGroup
              tag="div"
              class="relative mt-4 flex flex-col gap-2"
              enter-active-class="transition duration-500 ease-out"
              enter-from-class="-translate-y-2 opacity-0"
              leave-active-class="absolute inset-x-0 transition duration-300"
              leave-to-class="opacity-0"
              move-class="transition duration-500"
            >
              <div
                v-for="notification in notifications"
                :key="notification.id"
                class="flex items-center gap-3 rounded-xl border border-white/[0.06] bg-white/[0.03] px-3.5 py-3"
              >
                <span
                  class="size-4 shrink-0"
                  :class="[notification.icon, notification.tone]"
                />
                <span class="min-w-0 flex-1">
                  <span class="block truncate text-sm font-medium">
                    {{ notification.title }}
                  </span>
                  <span class="block truncate text-xs text-[#929cad]">
                    {{ notification.detail }}
                  </span>
                </span>
                <span class="shrink-0 text-xs text-[#566174]">
                  {{ relativeTime(notification.at) }}
                </span>
              </div>
            </TransitionGroup>
            <p class="mt-4 text-center text-[11px] text-[#566174]">
              {{ content.inboxCaption }}
            </p>
          </div>
        </div>
      </section>

      <section class="border-y border-white/[0.06] bg-white/[0.015]">
        <div
          class="mx-auto flex max-w-7xl flex-col items-center gap-6 px-6 py-10 sm:px-10 lg:flex-row lg:justify-between"
        >
          <p class="text-sm font-medium text-[#929cad]">
            {{ content.channelsTitle }}
          </p>
          <ul class="flex flex-wrap justify-center gap-x-8 gap-y-4">
            <li
              v-for="channel in channels"
              :key="channel.label"
              class="inline-flex items-center gap-2 text-sm font-medium text-[#dce2eb]"
            >
              <span class="size-5 text-[#93c5fd]" :class="channel.icon" />
              {{ channel.label }}
            </li>
          </ul>
        </div>
      </section>

      <section class="mx-auto max-w-7xl px-6 py-16 sm:px-10">
        <dl
          class="grid grid-cols-2 gap-px overflow-hidden rounded-2xl border border-white/[0.08] bg-white/[0.06] lg:grid-cols-4"
        >
          <div
            v-for="stat in stats"
            :key="stat.label"
            class="bg-[#080b12] px-6 py-8 text-center"
          >
            <dt
              class="bg-gradient-to-b from-white to-[#93c5fd] bg-clip-text text-4xl font-semibold tracking-[-0.03em] text-transparent"
            >
              {{ stat.value }}
            </dt>
            <dd class="mt-2 text-sm leading-5 text-[#929cad]">
              {{ stat.label }}
            </dd>
          </div>
        </dl>
      </section>

      <section
        id="como-funciona"
        class="mx-auto max-w-7xl scroll-mt-20 px-6 py-24 sm:px-10 lg:py-32"
      >
        <div class="mx-auto max-w-2xl text-center">
          <p
            class="text-xs font-semibold uppercase tracking-[0.2em] text-[#93c5fd]"
          >
            {{ content.stepsEyebrow }}
          </p>
          <h2
            class="mt-4 text-3xl font-semibold tracking-[-0.03em] sm:text-5xl"
          >
            {{ content.stepsTitle }}
          </h2>
          <p class="mt-5 text-lg leading-8 text-[#929cad]">
            {{ content.stepsDescription }}
          </p>
        </div>
        <ol class="relative mt-16 grid gap-4 md:grid-cols-5">
          <div
            class="pointer-events-none absolute inset-x-[10%] top-9 hidden h-px bg-gradient-to-r from-transparent via-[#60a5fa]/40 to-transparent md:block"
          />
          <li
            v-for="(step, index) in steps"
            :key="step.title"
            :class="card"
            class="p-5"
            @pointermove="trackPointer"
          >
            <div :class="cardGlow" />
            <div :class="cardShine" />
            <div class="flex items-center justify-between">
              <span
                class="flex size-10 items-center justify-center rounded-xl bg-[#087cff]/15 text-[#93c5fd] ring-1 ring-[#60a5fa]/20"
              >
                <span class="size-5" :class="step.icon" />
              </span>
              <span class="text-xs font-semibold text-[#566174]">
                {{ String(index + 1).padStart(2, '0') }}
              </span>
            </div>
            <h3 class="mt-5 text-base font-semibold">{{ step.title }}</h3>
            <p class="mt-2 text-sm leading-6 text-[#929cad]">{{ step.text }}</p>
          </li>
        </ol>
      </section>

      <section
        id="recursos"
        class="mx-auto max-w-7xl scroll-mt-20 px-6 pb-24 sm:px-10 lg:pb-32"
      >
        <div class="max-w-2xl">
          <p
            class="text-xs font-semibold uppercase tracking-[0.2em] text-[#93c5fd]"
          >
            {{ content.featuresEyebrow }}
          </p>
          <h2
            class="mt-4 text-3xl font-semibold tracking-[-0.03em] sm:text-5xl"
          >
            {{ content.featuresTitle }}
          </h2>
        </div>
        <div class="mt-14 grid gap-4 md:grid-cols-3">
          <article
            v-for="feature in features"
            :key="feature.title"
            :class="[card, { 'md:col-span-2': feature.wide }]"
            class="p-7 transition duration-300 hover:-translate-y-1"
            @pointermove="trackPointer"
          >
            <div :class="cardGlow" />
            <div :class="cardShine" />
            <span
              class="flex size-11 items-center justify-center rounded-xl bg-[#087cff]/15 text-[#93c5fd] ring-1 ring-[#60a5fa]/20"
            >
              <span class="size-5" :class="feature.icon" />
            </span>
            <h3 class="mt-6 text-xl font-semibold tracking-tight">
              {{ feature.title }}
            </h3>
            <p class="mt-3 max-w-md text-sm leading-6 text-[#929cad]">
              {{ feature.text }}
            </p>
          </article>
        </div>
      </section>

      <section
        id="seguranca"
        class="mx-auto max-w-7xl scroll-mt-20 px-6 pb-24 sm:px-10 lg:pb-32"
      >
        <div
          class="grid gap-12 rounded-3xl border border-white/[0.06] bg-white/[0.02] p-8 sm:p-12 lg:grid-cols-[0.8fr_1.2fr]"
        >
          <div>
            <p
              class="text-xs font-semibold uppercase tracking-[0.2em] text-[#93c5fd]"
            >
              {{ content.securityEyebrow }}
            </p>
            <h2
              class="mt-4 text-3xl font-semibold tracking-[-0.03em] sm:text-4xl"
            >
              {{ content.securityTitle }}
            </h2>
          </div>
          <ul class="grid gap-6 sm:grid-cols-2">
            <li v-for="item in security" :key="item.title" class="flex gap-4">
              <span
                class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-[#34d399]/10 text-[#6ee7b7]"
              >
                <span class="size-5" :class="item.icon" />
              </span>
              <span>
                <span class="block font-semibold">{{ item.title }}</span>
                <span class="mt-1 block text-sm leading-6 text-[#929cad]">
                  {{ item.text }}
                </span>
              </span>
            </li>
          </ul>
        </div>
      </section>

      <section class="mx-auto max-w-7xl px-6 pb-24 sm:px-10">
        <div
          :class="card"
          class="px-8 py-16 text-center sm:px-16"
          @pointermove="trackPointer"
        >
          <div :class="cardGlow" />
          <div :class="cardShine" />
          <div
            class="pointer-events-none absolute left-1/2 top-0 -z-10 size-[30rem] -translate-x-1/2 -translate-y-1/2 rounded-full bg-[#2a6bff]/25 blur-[100px]"
          />
          <h2
            class="mx-auto max-w-2xl text-3xl font-semibold tracking-[-0.03em] sm:text-5xl"
          >
            {{ content.ctaTitle }}
          </h2>
          <p class="mx-auto mt-5 max-w-lg text-lg text-[#929cad]">
            {{ content.ctaDescription }}
          </p>
          <a
            href="/app/login"
            class="group mt-10 inline-flex items-center gap-2 rounded-xl bg-white px-6 py-3.5 text-base font-semibold text-[#05070d] transition duration-200 hover:-translate-y-0.5 hover:bg-[#eff6ff] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#93c5fd] focus-visible:ring-offset-2 focus-visible:ring-offset-[#05070d]"
          >
            {{ content.access }}
            <span
              class="i-lucide-arrow-up-right size-5 transition-transform group-hover:-translate-y-0.5 group-hover:translate-x-0.5"
            />
          </a>
        </div>
      </section>
    </main>

    <footer class="border-t border-white/[0.06]">
      <div
        class="mx-auto flex max-w-7xl flex-col gap-4 px-6 py-8 text-sm text-[#566174] sm:flex-row sm:items-center sm:justify-between sm:px-10"
      >
        <span class="flex items-center gap-3">
          <AlvoradaWordmark tone="light" />
          <span>{{ content.company }}</span>
        </span>
        <span>{{ content.footerNote }}</span>
      </div>
    </footer>
  </div>
</template>
