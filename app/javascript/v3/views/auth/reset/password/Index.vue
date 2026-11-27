<script>
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required, minLength, email } from '@vuelidate/validators';
import { resetPassword } from '../../../../api/auth';
import AuthLayout from '../../../../components/AuthLayout.vue';
import Spinner from 'shared/components/Spinner.vue';

export default {
  components: { AuthLayout, Spinner },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      credentials: { email: '' },
      isLoading: false,
      // Shown in place of the form once the link was requested.
      sent: false,
    };
  },
  validations() {
    return {
      credentials: {
        email: { required, email, minLength: minLength(4) },
      },
    };
  },
  methods: {
    submit() {
      this.isLoading = true;
      resetPassword(this.credentials)
        .then(() => {
          this.sent = true;
        })
        .catch(error => {
          useAlert(
            error?.response?.data?.message ||
              this.$t('RESET_PASSWORD.API.ERROR_MESSAGE'),
            { status: 'error' }
          );
        })
        .finally(() => {
          this.isLoading = false;
        });
    },
  },
};
</script>

<template>
  <AuthLayout>
    <template v-if="sent">
      <span
        class="flex items-center justify-center rounded-lg size-11 bg-[#2563eb]/15 text-[#60a5fa]"
      >
        <span class="i-lucide-mail-check size-5" />
      </span>
      <h1 class="mt-6 auth-title">{{ $t('RESET_PASSWORD.SENT_TITLE') }}</h1>
      <p class="auth-description">
        {{
          $t('RESET_PASSWORD.SENT_DESCRIPTION', { email: credentials.email })
        }}
      </p>
      <button type="button" class="mt-8 auth-button" @click="sent = false">
        {{ $t('RESET_PASSWORD.SEND_AGAIN') }}
      </button>
    </template>

    <template v-else>
      <h1 class="auth-title">{{ $t('RESET_PASSWORD.TITLE') }}</h1>
      <p class="auth-description">{{ $t('RESET_PASSWORD.DESCRIPTION') }}</p>

      <form class="mt-8 space-y-6" @submit.prevent="submit">
        <label class="block">
          <span class="auth-label">{{ $t('RESET_PASSWORD.EMAIL.LABEL') }}</span>
          <span class="relative block">
            <span class="auth-input-icon i-lucide-mail" />
            <input
              v-model.trim="credentials.email"
              name="email_address"
              type="email"
              autocomplete="username"
              required
              class="auth-input"
              :class="{ '!border-[#f87171]': v$.credentials.email.$error }"
              :placeholder="$t('RESET_PASSWORD.EMAIL.PLACEHOLDER')"
              @blur="v$.credentials.email.$touch"
            />
          </span>
          <span v-if="v$.credentials.email.$error" class="block auth-error">
            {{ $t('RESET_PASSWORD.EMAIL.ERROR') }}
          </span>
        </label>
        <button
          type="submit"
          data-testid="submit_button"
          class="auth-button"
          :disabled="v$.credentials.email.$invalid || isLoading"
        >
          <Spinner v-if="isLoading" size="small" />
          <template v-else>{{ $t('RESET_PASSWORD.SUBMIT') }}</template>
        </button>
      </form>
    </template>

    <router-link
      to="/app/login"
      class="inline-flex items-center gap-2 mt-8 text-sm auth-link"
    >
      <span class="i-lucide-arrow-left size-4" />
      {{ $t('RESET_PASSWORD.BACK_TO_LOGIN') }}
    </router-link>
  </AuthLayout>
</template>
