<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import axios from 'axios';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import { frontendURL } from 'dashboard/helper/URLHelper';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const password = ref('');
const passwordConfirmation = ref('');
const isSaving = ref(false);
const errorMessage = ref('');

const isValid = computed(
  () =>
    password.value.length >= 6 &&
    /[A-Z]/.test(password.value) &&
    /[a-z]/.test(password.value) &&
    /\d/.test(password.value) &&
    /[!@#$%^&*()_+\-=\[\]{}|']/.test(password.value) &&
    password.value === passwordConfirmation.value
);

const changePassword = async () => {
  errorMessage.value = '';
  if (!isValid.value) {
    errorMessage.value = t('CRM.FORCED_PASSWORD.VALIDATION_ERROR');
    return;
  }

  isSaving.value = true;
  try {
    await axios.post('/api/v1/password_change', {
      password_change: {
        password: password.value,
        password_confirmation: passwordConfirmation.value,
      },
    });
    await store.dispatch('setUser');
    useAlert(t('CRM.FORCED_PASSWORD.SUCCESS'));
    router.replace(
      frontendURL(`accounts/${route.params.accountId}/dashboard`)
    );
  } catch (error) {
    errorMessage.value =
      error.response?.data?.error ||
      error.response?.data?.message ||
      t('CRM.FORCED_PASSWORD.SAVE_ERROR');
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <main class="flex min-h-screen items-center justify-center bg-n-background p-6">
    <section class="w-full max-w-md rounded-2xl border border-n-weak bg-n-solid-1 p-6 shadow-sm">
      <h1 class="text-heading-2 text-n-slate-12">
        {{ $t('CRM.FORCED_PASSWORD.TITLE') }}
      </h1>
      <p class="mt-2 text-sm text-n-slate-11">
        {{ $t('CRM.FORCED_PASSWORD.DESCRIPTION') }}
      </p>
      <form class="mt-6 space-y-4" @submit.prevent="changePassword">
        <label class="block text-sm font-medium text-n-slate-12">
          {{ $t('CRM.FORCED_PASSWORD.NEW_PASSWORD') }}
          <input
            v-model="password"
            class="mt-2 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-n-slate-12"
            type="password"
            autocomplete="new-password"
            required
          />
        </label>
        <label class="block text-sm font-medium text-n-slate-12">
          {{ $t('CRM.FORCED_PASSWORD.CONFIRM_PASSWORD') }}
          <input
            v-model="passwordConfirmation"
            class="mt-2 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-n-slate-12"
            type="password"
            autocomplete="new-password"
            required
          />
        </label>
        <p v-if="errorMessage" class="text-sm text-n-ruby-11">{{ errorMessage }}</p>
        <Button
          class="w-full"
          type="submit"
          :label="$t('CRM.FORCED_PASSWORD.SUBMIT')"
          :is-loading="isSaving"
        />
      </form>
    </section>
  </main>
</template>
