<script>
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import AuthLayout from '../../../components/AuthLayout.vue';
import Spinner from 'shared/components/Spinner.vue';
import { DEFAULT_REDIRECT_URL } from 'dashboard/constants/globals';
import { setNewPassword } from '../../../api/auth';

export default {
  components: { AuthLayout, Spinner },
  props: {
    resetPasswordToken: { type: String, default: '' },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      // We need to initialize the component with any
      // properties that will be used in it
      credentials: {
        confirmPassword: '',
        password: '',
      },
      newPasswordAPI: {
        message: '',
        showLoading: false,
      },
      error: '',
      showPassword: false,
    };
  },
  mounted() {
    // If url opened without token
    // redirect to login
    if (!this.resetPasswordToken) {
      window.location = DEFAULT_REDIRECT_URL;
    }
  },
  validations: {
    credentials: {
      password: {
        required,
        minLength: minLength(6),
      },
      confirmPassword: {
        required,
        minLength: minLength(6),
        isEqPassword(value) {
          if (value !== this.credentials.password) {
            return false;
          }
          return true;
        },
      },
    },
  },
  methods: {
    showAlertMessage(message) {
      // Reset loading, current selected agent
      this.newPasswordAPI.showLoading = false;
      useAlert(message, { status: 'error' });
    },
    submitForm() {
      this.newPasswordAPI.showLoading = true;
      const credentials = {
        confirmPassword: this.credentials.confirmPassword,
        password: this.credentials.password,
        resetPasswordToken: this.resetPasswordToken,
      };
      setNewPassword(credentials)
        .then(() => {
          window.location = DEFAULT_REDIRECT_URL;
        })
        .catch(error => {
          this.showAlertMessage(
            error?.message || this.$t('SET_NEW_PASSWORD.API.ERROR_MESSAGE')
          );
        });
    },
  },
};
</script>

<template>
  <AuthLayout>
    <h1 class="auth-title">{{ $t('SET_NEW_PASSWORD.TITLE') }}</h1>
    <p class="auth-description">{{ $t('SET_NEW_PASSWORD.DESCRIPTION') }}</p>

    <form class="mt-8 space-y-5" @submit.prevent="submitForm">
      <label class="block">
        <span class="auth-label">{{
          $t('SET_NEW_PASSWORD.PASSWORD.LABEL')
        }}</span>
        <span class="relative block">
          <span class="auth-input-icon i-lucide-lock" />
          <input
            v-model="credentials.password"
            name="password"
            :type="showPassword ? 'text' : 'password'"
            autocomplete="new-password"
            class="auth-input !pr-12"
            :class="{ '!border-[#f87171]': v$.credentials.password.$error }"
            :placeholder="$t('SET_NEW_PASSWORD.PASSWORD.PLACEHOLDER')"
            @blur="v$.credentials.password.$touch"
          />
          <button
            type="button"
            class="absolute flex items-center justify-center -translate-y-1/2 rounded-md right-2 top-1/2 size-8 text-[#64748b] hover:text-[#e2e8f0]"
            :aria-label="$t('SET_NEW_PASSWORD.TOGGLE_VISIBILITY')"
            @click="showPassword = !showPassword"
          >
            <span
              class="size-4"
              :class="showPassword ? 'i-lucide-eye-off' : 'i-lucide-eye'"
            />
          </button>
        </span>
        <span v-if="v$.credentials.password.$error" class="block auth-error">
          {{ $t('SET_NEW_PASSWORD.PASSWORD.ERROR') }}
        </span>
      </label>

      <label class="block">
        <span class="auth-label">
          {{ $t('SET_NEW_PASSWORD.CONFIRM_PASSWORD.LABEL') }}
        </span>
        <span class="relative block">
          <span class="auth-input-icon i-lucide-lock-keyhole" />
          <input
            v-model="credentials.confirmPassword"
            name="confirm_password"
            :type="showPassword ? 'text' : 'password'"
            autocomplete="new-password"
            class="auth-input"
            :class="{
              '!border-[#f87171]': v$.credentials.confirmPassword.$error,
            }"
            :placeholder="$t('SET_NEW_PASSWORD.CONFIRM_PASSWORD.PLACEHOLDER')"
            @blur="v$.credentials.confirmPassword.$touch"
          />
        </span>
        <span
          v-if="v$.credentials.confirmPassword.$error"
          class="block auth-error"
        >
          {{ $t('SET_NEW_PASSWORD.CONFIRM_PASSWORD.ERROR') }}
        </span>
      </label>

      <button
        type="submit"
        data-testid="submit_button"
        class="auth-button !mt-7"
        :disabled="
          v$.credentials.password.$invalid ||
          v$.credentials.confirmPassword.$invalid ||
          newPasswordAPI.showLoading
        "
      >
        <Spinner v-if="newPasswordAPI.showLoading" size="small" />
        <template v-else>{{ $t('SET_NEW_PASSWORD.SUBMIT') }}</template>
      </button>
    </form>
  </AuthLayout>
</template>
