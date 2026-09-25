<script setup>
const content = {
  initial: 'A',
  logoUrl: '/brand-assets/alvorada-logo.png',
  platform: 'AlvoChat',
  company: 'Comercial Alvorada',
  eyebrow: 'Central de atendimento e vendas',
  title: 'Sua equipe perto de cada oportunidade.',
  description:
    'O AlvoChat organiza as conversas que chegam, distribui o trabalho e dá à operação a clareza para avançar todos os dias.',
  access: 'Entrar no AlvoChat',
  detail: 'Feito para a operação Comercial Alvorada.',
  previewTitle: 'Visão da operação',
  previewSubtitle: 'Hoje, sua equipe está em movimento.',
  metricLabel: 'Oportunidades em acompanhamento',
  metricValue: '24',
  metricTrend: '+18% nesta semana',
  conversationsTitle: 'Conversas que pedem atenção',
  conversations: [
    {
      initials: 'MS',
      name: 'Mariana S.',
      message: 'Gostaria de receber uma proposta.',
      time: 'agora',
      color: 'bg-[#DCE9FF] text-[#1755B7]',
    },
    {
      initials: 'RB',
      name: 'Rafael B.',
      message: 'Podemos seguir com o pedido?',
      time: '12 min',
      color: 'bg-[#E9E4FF] text-[#5B47B3]',
    },
  ],
  footer: 'Atendimento, relacionamento e resultado em um só fluxo.',
  footerBrand: 'AlvoChat · Comercial Alvorada',
};
</script>

<template>
  <main class="min-h-screen overflow-hidden bg-[#071A4A] text-white">
    <div
      class="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_8%_0%,rgba(48,107,226,0.54),transparent_34%),radial-gradient(circle_at_85%_65%,rgba(19,75,186,0.34),transparent_30%)]"
    />
    <div
      class="relative mx-auto flex min-h-screen max-w-7xl flex-col px-6 py-7 sm:px-10 lg:px-12"
    >
      <header
        class="flex items-center justify-between motion-safe:animate-fade-in-up"
      >
        <a href="/" class="flex items-center" :aria-label="content.company">
          <span
            class="inline-flex rounded-xl bg-white px-3 py-2 shadow-lg shadow-blue-950/20"
          >
            <img
              :src="content.logoUrl"
              :alt="content.company"
              class="h-12 w-auto"
            />
          </span>
        </a>
        <a
          href="/app/login"
          class="rounded-xl border border-white/15 bg-white/10 px-5 py-2.5 text-sm font-semibold text-white backdrop-blur transition duration-300 hover:-translate-y-0.5 hover:bg-white/20 focus:outline-none focus:ring-2 focus:ring-white focus:ring-offset-2 focus:ring-offset-[#071A4A]"
        >
          {{ content.access }}
        </a>
      </header>

      <section
        class="grid flex-1 items-center gap-14 py-16 lg:grid-cols-[0.96fr_1.04fr] lg:gap-20 lg:py-20"
      >
        <div class="max-w-xl motion-safe:animate-fade-in-up">
          <p
            class="text-sm font-medium tracking-[0.16em] text-blue-200 uppercase"
          >
            {{ content.eyebrow }}
          </p>
          <h1
            class="mt-6 text-5xl font-semibold leading-[1.06] tracking-tight sm:text-6xl lg:text-[4.4rem]"
          >
            {{ content.title }}
          </h1>
          <p class="mt-7 max-w-lg text-lg leading-8 text-blue-100 sm:text-xl">
            {{ content.description }}
          </p>
          <div class="mt-10 flex flex-wrap items-center gap-5">
            <a
              href="/app/login"
              class="group inline-flex items-center gap-2 rounded-xl bg-white px-6 py-3.5 text-base font-semibold text-[#0C4BB4] shadow-xl shadow-blue-950/25 transition duration-300 hover:-translate-y-1 hover:shadow-2xl focus:outline-none focus:ring-2 focus:ring-white focus:ring-offset-2 focus:ring-offset-[#071A4A]"
            >
              {{ content.access }}
              <span
                class="i-lucide-arrow-up-right size-5 transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5"
              />
            </a>
            <span class="inline-flex items-center gap-2 text-sm text-blue-100">
              <span class="i-lucide-circle-check-big size-5 text-[#8DB7FF]" />
              {{ content.detail }}
            </span>
          </div>
        </div>

        <div
          class="relative mx-auto w-full max-w-xl motion-safe:animate-fade-in-up"
        >
          <div
            class="absolute -inset-8 rounded-[3rem] bg-blue-400/10 blur-3xl"
          />
          <div
            class="relative overflow-hidden rounded-[2rem] border border-white/15 bg-[#F7F9FC] p-5 text-[#14213D] shadow-2xl shadow-blue-950/40 sm:p-7"
          >
            <div
              class="flex items-start justify-between gap-4 border-b border-[#E1E7F0] pb-6"
            >
              <div>
                <p class="text-lg font-semibold tracking-tight">
                  {{ content.previewTitle }}
                </p>
                <p class="mt-1 text-sm text-[#718096]">
                  {{ content.previewSubtitle }}
                </p>
              </div>
              <span
                class="inline-flex items-center gap-2 rounded-full bg-[#E9F8F0] px-3 py-1.5 text-xs font-semibold text-[#19734A]"
              >
                <span
                  class="size-1.5 rounded-full bg-[#28B878] motion-safe:animate-pulse"
                />
                {{ content.company }}
              </span>
            </div>

            <div class="mt-6 grid gap-4 sm:grid-cols-[0.8fr_1.2fr]">
              <section class="rounded-2xl bg-[#EAF1FF] p-5">
                <span
                  class="flex size-10 items-center justify-center rounded-xl bg-white text-[#1755B7] shadow-sm"
                  ><span class="i-lucide-trending-up size-5"
                /></span>
                <p class="mt-5 text-sm leading-5 text-[#55709D]">
                  {{ content.metricLabel }}
                </p>
                <p
                  class="mt-1 text-4xl font-semibold tracking-tight text-[#123B81]"
                >
                  {{ content.metricValue }}
                </p>
                <p class="mt-3 text-xs font-semibold text-[#1D6FD6]">
                  {{ content.metricTrend }}
                </p>
              </section>

              <section class="rounded-2xl border border-[#E1E7F0] bg-white p-5">
                <div class="flex items-center justify-between gap-3">
                  <p class="text-sm font-semibold">
                    {{ content.conversationsTitle }}
                  </p>
                  <span
                    class="i-lucide-message-square-text size-5 text-[#4876BE]"
                  />
                </div>
                <div class="mt-4 divide-y divide-[#EDF1F6]">
                  <div
                    v-for="conversation in content.conversations"
                    :key="conversation.name"
                    class="flex items-center gap-3 py-3 first:pt-0 last:pb-0"
                  >
                    <span
                      :class="conversation.color"
                      class="flex size-9 shrink-0 items-center justify-center rounded-full text-xs font-bold"
                      >{{ conversation.initials }}</span
                    >
                    <span class="min-w-0 flex-1">
                      <span class="block truncate text-sm font-semibold">{{
                        conversation.name
                      }}</span>
                      <span
                        class="mt-0.5 block truncate text-xs text-[#718096]"
                        >{{ conversation.message }}</span
                      >
                    </span>
                    <span class="text-xs text-[#94A3B8]">{{
                      conversation.time
                    }}</span>
                  </div>
                </div>
              </section>
            </div>

            <div
              class="mt-5 flex items-center gap-3 rounded-2xl bg-[#102E67] px-5 py-4 text-white"
            >
              <span
                class="flex size-9 shrink-0 items-center justify-center rounded-lg bg-white/12"
                ><span class="i-lucide-users-round size-5 text-[#B9D1FF]"
              /></span>
              <p class="text-sm leading-5 text-blue-50">{{ content.footer }}</p>
            </div>
          </div>
        </div>
      </section>

      <footer
        class="flex flex-col gap-2 border-t border-white/10 pt-6 text-xs text-blue-200 sm:flex-row sm:items-center sm:justify-between"
      >
        <span>{{ content.footerBrand }}</span>
        <span>{{ content.footer }}</span>
      </footer>
    </div>
  </main>
</template>
