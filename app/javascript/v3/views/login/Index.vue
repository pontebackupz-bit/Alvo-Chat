<script>
// utils and composables
import { login } from '../../api/auth';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { SESSION_STORAGE_KEYS } from 'dashboard/constants/sessionStorage';
import SessionStorage from 'shared/helpers/sessionStorage';
import AnalyticsHelper from 'dashboard/helper/AnalyticsHelper';
import { SESSION_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';

// components
import GoogleOAuthButton from '../../components/GoogleOauth/Button.vue';
import Spinner from 'shared/components/Spinner.vue';
import MfaVerification from 'dashboard/components/auth/MfaVerification.vue';
import SessionLimitOverlay from 'dashboard/components/auth/SessionLimitOverlay.vue';
import AuthLayout from '../../components/AuthLayout.vue';

const ERROR_MESSAGES = {
  'no-account-found': 'LOGIN.OAUTH.NO_ACCOUNT_FOUND',
  'business-account-only': 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY',
  'saml-authentication-failed': 'LOGIN.SAML.API.ERROR_MESSAGE',
  'saml-not-enabled': 'LOGIN.SAML.API.ERROR_MESSAGE',
};

const IMPERSONATION_URL_SEARCH_KEY = 'impersonation';
const USER_NOT_CONFIRMED_ERROR_CODE = 'user_not_confirmed';
const BRAND = {
  loginTitle: 'Entrar na sua conta',
  loginDescription: 'Bem-vindo de volta! Acesse sua central de atendimento.',
  divider: 'ou com e-mail',
  showPassword: 'Mostrar senha',
  hidePassword: 'Ocultar senha',
};

export default {
  components: {
    GoogleOAuthButton,
    Spinner,
    MfaVerification,
    SessionLimitOverlay,
    AuthLayout,
  },
  props: {
    ssoAuthToken: { type: String, default: '' },
    ssoAccountId: { type: String, default: '' },
    ssoConversationId: { type: String, default: '' },
    email: { type: String, default: '' },
    authError: { type: String, default: '' },
  },
  setup() {
    return {
      brand: BRAND,
      v$: useVuelidate(),
    };
  },
  data() {
    return {
      // We need to initialize the component with any
      // properties that will be used in it
      credentials: {
        email: '',
        password: '',
      },
      loginApi: {
        message: '',
        showLoading: false,
        hasErrored: false,
      },
      error: '',
      showPassword: false,
      mfaRequired: false,
      mfaToken: null,
      sessionsLimitReached: false,
      limitedSessions: [],
    };
  },
  validations() {
    return {
      credentials: {
        password: {
          required,
        },
        email: {
          required,
          email,
        },
      },
    };
  },
  computed: {
    ...mapGetters({ globalConfig: 'globalConfig/get' }),
    allowedLoginMethods() {
      return window.chatwootConfig.allowedLoginMethods || ['email'];
    },
    showGoogleOAuth() {
      return (
        this.allowedLoginMethods.includes('google_oauth') &&
        Boolean(window.chatwootConfig.googleOAuthClientId)
      );
    },
    showSignupLink() {
      return window.chatwootConfig.signupEnabled === 'true';
    },
  },
  created() {
    if (this.ssoAuthToken) {
      this.submitLogin();
    }
    if (this.authError) {
      const messageKey = ERROR_MESSAGES[this.authError] ?? 'LOGIN.API.UNAUTH';
      // Use a method to get the translated text to avoid dynamic key warning
      const translatedMessage = this.getTranslatedMessage(messageKey);
      useAlert(translatedMessage);
      // wait for idle state
      this.requestIdleCallbackPolyfill(() => {
        // Remove the error query param from the url
        const { query } = this.$route;
        this.$router.replace({ query: { ...query, error: undefined } });
      });
    }
  },
  methods: {
    getTranslatedMessage(key) {
      // Avoid dynamic key warning by handling each case explicitly
      switch (key) {
        case 'LOGIN.OAUTH.NO_ACCOUNT_FOUND':
          return this.$t('LOGIN.OAUTH.NO_ACCOUNT_FOUND');
        case 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY':
          return this.$t('LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY');
        case 'LOGIN.API.UNAUTH':
        default:
          return this.$t('LOGIN.API.UNAUTH');
      }
    },
    // TODO: Remove this when Safari gets wider support
    // Ref: https://caniuse.com/requestidlecallback
    //
    requestIdleCallbackPolyfill(callback) {
      if (window.requestIdleCallback) {
        window.requestIdleCallback(callback);
      } else {
        // Fallback for safari
        // Using a delay of 0 allows the callback to be executed asynchronously
        // in the next available event loop iteration, similar to requestIdleCallback
        setTimeout(callback, 0);
      }
    },
    showAlertMessage(message) {
      // Reset loading, current selected agent
      this.loginApi.showLoading = false;
      this.loginApi.message = message;
      useAlert(this.loginApi.message);
    },
    handleImpersonation() {
      // Detects impersonation mode via URL and sets a session flag to prevent user settings changes during impersonation.
      const urlParams = new URLSearchParams(window.location.search);
      const impersonation = urlParams.get(IMPERSONATION_URL_SEARCH_KEY);
      if (impersonation) {
        SessionStorage.set(SESSION_STORAGE_KEYS.IMPERSONATION_USER, true);
      }
    },
    submitLogin() {
      this.loginApi.hasErrored = false;
      this.loginApi.showLoading = true;

      const credentials = {
        email: this.email
          ? decodeURIComponent(this.email)
          : this.credentials.email,
        password: this.credentials.password,
        sso_auth_token: this.ssoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
      };

      login(credentials)
        .then(result => {
          // Check if MFA is required
          if (result?.mfaRequired) {
            this.loginApi.showLoading = false;
            this.mfaRequired = true;
            this.mfaToken = result.mfaToken;
            return;
          }

          // Check if sessions limit reached
          if (result?.sessionsLimitReached) {
            this.loginApi.showLoading = false;
            this.sessionsLimitReached = true;
            this.limitedSessions = result.sessions;
            AnalyticsHelper.track(SESSION_EVENTS.LIMIT_HIT);
            return;
          }

          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          if (response?.errorCode === USER_NOT_CONFIRMED_ERROR_CODE) {
            this.loginApi.showLoading = false;
            this.$router.push({
              name: 'auth_verify_email',
              state: { email: credentials.email },
            });
            return;
          }

          // Reset URL Params if the authentication is invalid
          if (this.email) {
            window.location = '/app/login';
          }
          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    submitFormLogin() {
      if (this.v$.credentials.email.$invalid && !this.email) {
        this.showAlertMessage(this.$t('LOGIN.EMAIL.ERROR'));
        return;
      }

      this.submitLogin();
    },
    handleMfaVerified() {
      // MFA verification successful, continue with login
      this.handleImpersonation();
      window.location = '/app';
    },
    handleMfaCancel() {
      // User cancelled MFA, reset state
      this.mfaRequired = false;
      this.mfaToken = null;
      this.credentials.password = '';
    },
    retryLoginWithParams(extraParams) {
      const credentials = {
        email: this.email
          ? decodeURIComponent(this.email)
          : this.credentials.email,
        password: this.credentials.password,
        sso_auth_token: this.ssoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
        ...extraParams,
      };

      this.sessionsLimitReached = false;
      this.limitedSessions = [];
      this.loginApi.showLoading = true;
      login(credentials)
        .then(result => {
          if (result?.sessionsLimitReached) {
            this.loginApi.showLoading = false;
            this.sessionsLimitReached = true;
            this.limitedSessions = result.sessions;
            AnalyticsHelper.track(SESSION_EVENTS.LIMIT_HIT);
            return;
          }
          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    handleSessionRevoke(sessionId) {
      this.retryLoginWithParams({ revoke_session_id: sessionId });
    },
    handleSessionRevokeAll() {
      this.retryLoginWithParams({ revoke_all_sessions: true });
    },
    handleSessionLimitCancel() {
      this.sessionsLimitReached = false;
      this.limitedSessions = [];
      this.credentials.password = '';
    },
  },
};
</script>

<template>
  <AuthLayout>
    <h2 class="auth-title">{{ brand.loginTitle }}</h2>
    <p class="auth-description">{{ brand.loginDescription }}</p>
    <p v-if="showSignupLink" class="mt-3 text-sm text-[#94a3b8]">
      {{ $t('COMMON.OR') }}
      <router-link to="auth/signup" class="auth-link">
        {{ $t('LOGIN.CREATE_NEW_ACCOUNT') }}
      </router-link>
    </p>

    <section v-if="sessionsLimitReached" class="mt-10">
      <SessionLimitOverlay
        :sessions="limitedSessions"
        @revoke="handleSessionRevoke"
        @revoke-all="handleSessionRevokeAll"
        @cancel="handleSessionLimitCancel"
      />
    </section>

    <section v-else-if="mfaRequired" class="mt-10">
      <MfaVerification
        :mfa-token="mfaToken"
        @verified="handleMfaVerified"
        @cancel="handleMfaCancel"
      />
    </section>

    <section
      v-else
      class="mt-8"
      :class="{ 'animate-wiggle': loginApi.hasErrored }"
    >
      <div v-if="!email">
        <div v-if="showGoogleOAuth" class="flex flex-col gap-6 mb-6">
          <GoogleOAuthButton />
          <div class="flex items-center gap-4">
            <span class="flex-1 h-px bg-white/10" />
            <span
              class="text-[11px] font-medium tracking-[0.2em] uppercase text-[#64748b]"
            >
              {{ brand.divider }}
            </span>
            <span class="flex-1 h-px bg-white/10" />
          </div>
        </div>

        <form class="space-y-5" @submit.prevent="submitFormLogin">
          <label class="block">
            <span class="auth-label">{{ $t('LOGIN.EMAIL.LABEL') }}</span>
            <span class="relative block">
              <span class="auth-input-icon i-lucide-mail" />
              <input
                v-model.trim="credentials.email"
                name="email_address"
                type="email"
                autocomplete="username"
                data-testid="email_input"
                tabindex="1"
                required
                :placeholder="$t('LOGIN.EMAIL.PLACEHOLDER')"
                class="auth-input"
                :class="{ '!border-[#f87171]': v$.credentials.email.$error }"
                @input="v$.credentials.email.$touch"
              />
            </span>
          </label>

          <label class="block">
            <span class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium text-[#e2e8f0]">
                {{ $t('LOGIN.PASSWORD.LABEL') }}
              </span>
              <router-link
                v-if="!globalConfig.disableUserProfileUpdate"
                to="auth/reset/password"
                class="text-xs auth-link"
                tabindex="4"
              >
                {{ $t('LOGIN.FORGOT_PASSWORD') }}
              </router-link>
            </span>
            <span class="relative block">
              <span class="auth-input-icon i-lucide-lock" />
              <input
                v-model="credentials.password"
                name="password"
                :type="showPassword ? 'text' : 'password'"
                autocomplete="current-password"
                data-testid="password_input"
                tabindex="2"
                required
                :placeholder="$t('LOGIN.PASSWORD.PLACEHOLDER')"
                class="auth-input !pr-12"
                :class="{
                  '!border-[#f87171]': v$.credentials.password.$error,
                }"
                @input="v$.credentials.password.$touch"
              />
              <button
                type="button"
                class="absolute flex items-center justify-center -translate-y-1/2 rounded-md right-2 top-1/2 size-8 text-[#64748b] hover:text-[#e2e8f0]"
                :aria-label="
                  showPassword ? brand.hidePassword : brand.showPassword
                "
                @click="showPassword = !showPassword"
              >
                <span
                  class="size-4"
                  :class="showPassword ? 'i-lucide-eye-off' : 'i-lucide-eye'"
                />
              </button>
            </span>
          </label>

          <button
            type="submit"
            data-testid="submit_button"
            tabindex="3"
            class="auth-button !mt-7"
            :disabled="loginApi.showLoading"
          >
            <Spinner v-if="loginApi.showLoading" size="small" />
            <template v-else>
              {{ $t('LOGIN.SUBMIT') }}
              <span class="i-lucide-arrow-right size-4" />
            </template>
          </button>
        </form>
      </div>
      <div v-else class="flex items-center justify-center py-8">
        <Spinner color-scheme="primary" size="" />
      </div>
    </section>
  </AuthLayout>
</template>
