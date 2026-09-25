<script setup>
const content = {
  eyebrow: 'Plataforma comercial integrada',
  title: 'Atendimento que vira resultado.',
  description:
    'Centralize conversas, oportunidades e indicadores em uma experiência criada para equipes comerciais de alta performance.',
  access: 'Acessar plataforma',
  features: [
    {
      title: 'Conversas conectadas',
      description: 'WhatsApp, canais e equipe trabalhando no mesmo contexto.',
      icon: 'i-lucide-messages-square',
    },
    {
      title: 'Visão de operação',
      description: 'Indicadores claros para acompanhar cada oportunidade.',
      icon: 'i-lucide-chart-no-axes-combined',
    },
    {
      title: 'Controle por equipe',
      description: 'Permissões e supervisão pensadas para a sua estrutura.',
      icon: 'i-lucide-shield-check',
    },
  ],
};

const installationName = window.globalConfig.installationName;
</script>

<template>
  <main class="min-h-screen overflow-hidden bg-[#071B4D] text-white">
    <div class="absolute inset-0 bg-[radial-gradient(circle_at_15%_20%,rgba(54,121,255,0.45),transparent_32%),radial-gradient(circle_at_80%_70%,rgba(20,74,190,0.55),transparent_34%)]" />
    <div class="relative mx-auto flex min-h-screen max-w-7xl flex-col px-6 py-7 sm:px-10 lg:px-12">
      <header class="flex items-center justify-between motion-safe:animate-fade-in-up">
        <a href="/" class="flex items-center" :aria-label="installationName">
          <img src="/brand-assets/logo_dark.svg" :alt="installationName" class="h-9 w-auto" />
        </a>
        <a href="/app/login" class="rounded-full border border-white/20 bg-white/10 px-5 py-2.5 text-sm font-semibold text-white backdrop-blur transition hover:-translate-y-0.5 hover:bg-white/20 focus:outline-none focus:ring-2 focus:ring-white focus:ring-offset-2 focus:ring-offset-[#071B4D]">
          {{ content.access }}
        </a>
      </header>

      <section class="grid flex-1 items-center gap-16 py-16 lg:grid-cols-[1.1fr_0.9fr] lg:py-24">
        <div class="max-w-2xl motion-safe:animate-fade-in-up">
          <p class="inline-flex rounded-full border border-blue-200/20 bg-blue-300/10 px-4 py-2 text-xs font-semibold tracking-[0.16em] text-blue-100 uppercase">
            {{ content.eyebrow }}
          </p>
          <h1 class="mt-7 text-5xl font-semibold leading-[1.05] tracking-tight sm:text-6xl lg:text-7xl">
            {{ content.title }}
          </h1>
          <p class="mt-7 max-w-xl text-lg leading-8 text-blue-100 sm:text-xl">
            {{ content.description }}
          </p>
          <div class="mt-10 flex flex-wrap items-center gap-4">
            <a href="/app/login" class="group inline-flex items-center gap-2 rounded-xl bg-white px-6 py-3.5 text-base font-semibold text-[#0C3A98] shadow-xl shadow-blue-950/20 transition hover:-translate-y-1 hover:shadow-2xl focus:outline-none focus:ring-2 focus:ring-white focus:ring-offset-2 focus:ring-offset-[#071B4D]">
              {{ content.access }}
              <span class="i-lucide-arrow-up-right size-5 transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5" />
            </a>
            <span class="inline-flex items-center gap-2 text-sm text-blue-100">
              <span class="i-lucide-circle-check-big size-5 text-blue-300" />
              {{ installationName }}
            </span>
          </div>
        </div>

        <div class="relative mx-auto w-full max-w-lg motion-safe:animate-fade-in-up">
          <div class="absolute -inset-8 rounded-[2.5rem] bg-blue-300/15 blur-3xl" />
          <div class="relative rounded-[2rem] border border-white/15 bg-white/10 p-5 shadow-2xl shadow-blue-950/30 backdrop-blur-xl sm:p-7">
            <div class="flex items-center justify-between border-b border-white/10 pb-5">
              <div class="flex items-center gap-3">
                <span class="flex size-10 items-center justify-center rounded-xl bg-white text-[#0C3A98]"><span class="i-lucide-sparkles size-5" /></span>
                <div>
                  <p class="text-sm font-semibold">{{ installationName }}</p>
                  <p class="mt-0.5 text-xs text-blue-200">Operação comercial</p>
                </div>
              </div>
              <span class="inline-flex items-center gap-1.5 rounded-full bg-emerald-400/15 px-3 py-1.5 text-xs font-medium text-emerald-200"><span class="size-1.5 rounded-full bg-emerald-300 motion-safe:animate-pulse" />Online</span>
            </div>
            <div class="mt-5 space-y-3">
              <div v-for="feature in content.features" :key="feature.title" class="group flex gap-4 rounded-2xl border border-white/10 bg-white/[0.06] p-4 transition duration-300 hover:-translate-y-1 hover:bg-white/[0.12]">
                <span :class="feature.icon" class="mt-0.5 size-6 shrink-0 text-blue-200" />
                <div>
                  <h2 class="text-sm font-semibold">{{ feature.title }}</h2>
                  <p class="mt-1 text-sm leading-6 text-blue-100">{{ feature.description }}</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <footer class="flex flex-col gap-2 border-t border-white/10 pt-6 text-xs text-blue-200 sm:flex-row sm:items-center sm:justify-between">
        <span>{{ installationName }}</span>
        <span>Atendimento, gestão e resultado em um só lugar.</span>
      </footer>
    </div>
  </main>
</template>
