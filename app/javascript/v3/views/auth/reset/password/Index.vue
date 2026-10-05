<script>
import { useBranding } from 'shared/composables/useBranding';
import { useMapGetter } from 'dashboard/composables/store';

export default {
  setup() {
    const { replaceInstallationName } = useBranding();
    const globalConfig = useMapGetter('globalConfig/get');
    return { replaceInstallationName, globalConfig };
  },
};
</script>

<template>
  <div
    class="flex flex-col justify-center w-full min-h-screen py-12 bg-n-brand/5 dark:bg-n-background sm:px-6 lg:px-8"
  >
    <div class="mb-6 text-center">
      <img
        :src="globalConfig.logo"
        :alt="globalConfig.installationName"
        class="inline-block w-auto h-8 dark:hidden"
      />
      <img
        v-if="globalConfig.logoDark"
        :src="globalConfig.logoDark"
        :alt="globalConfig.installationName"
        class="hidden w-auto h-8 dark:inline-block"
      />
    </div>
    <section
      class="bg-white shadow sm:mx-auto sm:w-full sm:max-w-lg dark:bg-n-solid-2 p-11 sm:shadow-lg sm:rounded-lg"
    >
      <h1
        class="mb-1 text-2xl font-medium tracking-tight text-left text-n-slate-12"
      >
        {{ $t('RESET_PASSWORD.TITLE') }}
      </h1>
      <p
        class="mb-4 text-sm font-normal leading-6 tracking-normal text-n-slate-11"
      >
        {{ replaceInstallationName($t('RESET_PASSWORD.DESCRIPTION')) }}
      </p>
      <p class="mt-4 -mb-1 text-sm text-n-slate-11">
        {{ $t('RESET_PASSWORD.GO_BACK_TO_LOGIN') }}
        <router-link to="/auth/login" class="text-link text-n-brand">
          {{ $t('COMMON.CLICK_HERE') }}.
        </router-link>
      </p>
    </section>
  </div>
</template>
