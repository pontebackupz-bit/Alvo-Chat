<script setup>
// Shared frame of the sign-in pages (login, password recovery, new
// password): the AlvoChat brand panel on the left and the form on the right.
// The `.auth-*` classes below style the forms placed in the slot.
import AlvoradaWordmark from 'shared/components/AlvoradaWordmark.vue';

const BRAND = {
  company: 'Comercial Alvorada',
  titleStart: 'Toda conversa pode',
  titleHighlight: 'virar resultado.',
  description:
    'WhatsApp, equipe e oportunidades em uma central de atendimento só.',
  features: [
    {
      icon: 'i-lucide-messages-square',
      title: 'WhatsApp e grupos em um só lugar',
      text: 'Receba e responda clientes e grupos direto pela plataforma.',
    },
    {
      icon: 'i-lucide-history',
      title: 'Histórico completo',
      text: 'As conversas que já estão no celular chegam junto com o número.',
    },
    {
      icon: 'i-lucide-shield-check',
      title: 'Equipe sob controle',
      text: 'Supervisores acompanham a equipe; cada um vê o que é seu.',
    },
  ],
  mockCustomer: 'Maria · Cliente',
  mockQuestion: 'Pode me mandar o orçamento?',
  mockAnswer: 'Claro! Já está no seu WhatsApp.',
  mockBadge: 'Conversa resolvida',
  mockBadgeDetail: 'Primeira resposta em 2 min',
  security: 'Conexão segura e criptografada',
};

// A fixed, quiet star field (no randomness, so it never jumps).
const stars = Array.from({ length: 24 }, (_, index) => ({
  id: index,
  style: {
    left: `${(index * 37) % 100}%`,
    top: `${(index * 53 + 11) % 100}%`,
    width: index % 5 === 0 ? '3px' : '2px',
    height: index % 5 === 0 ? '3px' : '2px',
    opacity: 0.2 + ((index * 7) % 10) / 25,
  },
}));
</script>

<template>
  <main
    class="grid min-h-screen bg-[#070a12] text-white lg:grid-cols-[minmax(0,1.05fr)_minmax(460px,0.95fr)]"
  >
    <section
      class="relative hidden overflow-hidden px-14 py-12 lg:flex lg:flex-col bg-[linear-gradient(160deg,#0c1840_0%,#0a1233_50%,#080c22_100%)]"
    >
      <div
        class="absolute inset-0 bg-[linear-gradient(rgba(255,255,255,0.03)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.03)_1px,transparent_1px)] bg-[size:48px_48px] [mask-image:radial-gradient(ellipse_at_30%_40%,black_30%,transparent_80%)]"
      />
      <div
        class="absolute -left-40 top-1/4 size-[32rem] rounded-full bg-[#1d4ed8]/20 blur-[150px]"
      />
      <span
        v-for="star in stars"
        :key="star.id"
        class="absolute bg-white rounded-full"
        :style="star.style"
      />

      <div class="relative z-10">
        <AlvoradaWordmark tone="light" size="large" :subtitle="false" />
      </div>

      <div class="relative z-10 flex flex-col justify-center flex-1 max-w-xl">
        <h1 class="text-5xl font-semibold leading-[1.08] tracking-[-0.035em]">
          {{ BRAND.titleStart }}
          <span class="block auth-highlight">
            {{ BRAND.titleHighlight }}
          </span>
        </h1>
        <p class="mt-5 text-lg leading-8 text-[#a7b3cf]">
          {{ BRAND.description }}
        </p>

        <ul class="mt-10 space-y-5">
          <li
            v-for="feature in BRAND.features"
            :key="feature.title"
            class="flex items-start gap-4"
          >
            <span
              class="flex items-center justify-center rounded-lg size-10 shrink-0 border border-white/10 bg-white/[0.05] text-[#93c5fd]"
            >
              <span class="size-5" :class="feature.icon" />
            </span>
            <span>
              <span class="block text-[15px] font-semibold text-white">
                {{ feature.title }}
              </span>
              <span class="block mt-0.5 text-sm leading-6 text-[#a7b3cf]">
                {{ feature.text }}
              </span>
            </span>
          </li>
        </ul>
      </div>

      <div class="relative z-10 h-56">
        <div
          class="absolute right-4 bottom-6 w-80 rounded-xl border border-white/10 bg-[#0f1a45] p-4"
        >
          <p class="flex items-center gap-2 text-xs text-[#a7b3cf]">
            <span
              class="flex items-center justify-center rounded-full size-6 bg-[#25d366]/15 text-[#4ade80]"
            >
              <span class="i-ri-whatsapp-line size-3.5" />
            </span>
            {{ BRAND.mockCustomer }}
          </p>
          <p
            class="mt-3 w-fit rounded-2xl rounded-tl-sm bg-white/10 px-3.5 py-2 text-sm text-[#e2e8f0]"
          >
            {{ BRAND.mockQuestion }}
          </p>
          <p
            class="mt-2 ml-auto w-fit rounded-2xl rounded-tr-sm bg-[#2563eb] px-3.5 py-2 text-sm text-white"
          >
            {{ BRAND.mockAnswer }}
          </p>
        </div>
        <div
          class="absolute bottom-0 left-0 w-64 rounded-xl border border-white/10 bg-[#13235a] p-4"
        >
          <p class="flex items-center gap-2 text-xs text-[#bfdbfe]">
            <span class="rounded-full size-2 bg-[#4ade80]" />
            {{ BRAND.mockBadge }}
          </p>
          <p class="mt-2 text-sm font-semibold text-white">
            {{ BRAND.mockBadgeDetail }}
          </p>
        </div>
      </div>
    </section>

    <section
      class="relative flex items-center justify-center px-6 py-12 sm:px-10 lg:px-16"
    >
      <div class="w-full max-w-[25rem]">
        <div class="mb-10 lg:hidden">
          <AlvoradaWordmark tone="light" :subtitle="false" />
        </div>
        <slot />
        <p
          class="flex items-center justify-center gap-2 mt-10 text-xs text-[#64748b]"
        >
          <span class="i-lucide-shield-check size-4 text-[#4ade80]" />
          {{ BRAND.security }}
        </p>
        <p class="mt-2 text-xs text-center text-[#475569]">
          {{ BRAND.company }}
        </p>
      </div>
    </section>
  </main>
</template>

<style>
/* The highlighted words flow continuously through the brand blues, with a
   brighter band passing over them. Without motion (system setting) they
   stay a plain light blue. */
.auth-highlight {
  color: #93c5fd;
  background-image: linear-gradient(
    90deg,
    #3b82f6 0%,
    #93c5fd 20%,
    #ffffff 30%,
    #a5b4fc 40%,
    #38bdf8 60%,
    #6366f1 80%,
    #3b82f6 100%
  );
  background-size: 200% auto;
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
  animation: auth-highlight-flow 3s linear infinite;
}

@keyframes auth-highlight-flow {
  from {
    background-position: 0% center;
  }

  to {
    background-position: -200% center;
  }
}

@media (prefers-reduced-motion: reduce) {
  .auth-highlight {
    animation: none;
    background-image: none;
    -webkit-text-fill-color: currentColor;
  }
}

.auth-title {
  @apply text-3xl font-semibold tracking-tight text-white;
}

.auth-description {
  @apply mt-2 text-[15px] leading-6 text-[#94a3b8];
}

.auth-label {
  @apply block mb-2 text-sm font-medium text-[#e2e8f0];
}

.auth-input {
  @apply block w-full h-11 pl-11 pr-4 rounded-lg border border-white/10 bg-white/[0.03] text-[15px] text-white outline-none transition-colors placeholder:text-[#475569] hover:border-white/20 focus:border-[#3b82f6] focus:bg-white/[0.05];
}

.auth-input-icon {
  @apply absolute -translate-y-1/2 pointer-events-none size-4 left-4 top-1/2 text-[#64748b];
}

.auth-error {
  @apply mt-1.5 text-xs text-[#f87171];
}

.auth-button {
  @apply flex items-center justify-center w-full gap-2 h-11 rounded-lg bg-[#2563eb] text-[15px] font-medium text-white transition-colors hover:bg-[#1d4ed8] disabled:opacity-60 disabled:cursor-not-allowed;
}

.auth-link {
  @apply font-medium text-[#60a5fa] hover:text-[#93c5fd];
}
</style>
