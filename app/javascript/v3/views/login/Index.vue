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
import SimpleDivider from '../../components/Divider/SimpleDivider.vue';
import FormInput from '../../components/Form/Input.vue';
import GoogleOAuthButton from '../../components/GoogleOauth/Button.vue';
import Spinner from 'shared/components/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import MfaVerification from 'dashboard/components/auth/MfaVerification.vue';
import SessionLimitOverlay from 'dashboard/components/auth/SessionLimitOverlay.vue';
import AlvoradaWordmark from 'shared/components/AlvoradaWordmark.vue';

const ERROR_MESSAGES = {
  'no-account-found': 'LOGIN.OAUTH.NO_ACCOUNT_FOUND',
  'business-account-only': 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY',
  'saml-authentication-failed': 'LOGIN.SAML.API.ERROR_MESSAGE',
  'saml-not-enabled': 'LOGIN.SAML.API.ERROR_MESSAGE',
};

const IMPERSONATION_URL_SEARCH_KEY = 'impersonation';
const USER_NOT_CONFIRMED_ERROR_CODE = 'user_not_confirmed';
const BRAND = {
  initial: 'A',
  platform: 'AlvoChat',
  company: 'Comercial Alvorada',
  eyebrow: 'Central comercial',
  title: 'Toda conversa pode virar resultado.',
  description:
    'O AlvoChat reúne atendimento, oportunidades e sua equipe em uma única operação, com contexto do início ao fim.',
  loginTitle: 'Acesse sua conta',
  loginDescription: 'Entre com seu e-mail corporativo para continuar.',
  security: 'Ambiente seguro para a equipe Comercial Alvorada.',
  benefits: [
    'Atenda clientes com histórico e contexto.',
    'Acompanhe as oportunidades que movimentam o negócio.',
    'Trabalhe em equipe com visibilidade e controle.',
  ],
};

export default {
  components: {
    FormInput,
    GoogleOAuthButton,
    Spinner,
    NextButton,
    SimpleDivider,
    MfaVerification,
    SessionLimitOverlay,
    AlvoradaWordmark,
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
  <main
    class="grid min-h-screen bg-[#F7F9FC] lg:grid-cols-[minmax(0,1.06fr)_minmax(480px,0.94fr)]"
  >
    <section
      class="relative hidden overflow-hidden bg-gradient-to-br from-[#071B4D] via-[#0C327F] to-[#1E5ED8] px-14 py-12 text-white lg:flex lg:flex-col lg:justify-between"
    >
      <div
        class="absolute -top-32 right-0 h-96 w-96 rounded-full bg-blue-300/10 blur-3xl"
      />
      <div
        class="absolute bottom-0 left-0 h-80 w-80 translate-x-[-35%] translate-y-[40%] rounded-full border border-white/10"
      />
      <div class="relative z-10">
        <AlvoradaWordmark tone="light" size="large" />
      </div>
      <div class="relative z-10 max-w-xl motion-safe:animate-fade-in-up">
        <p
          class="text-sm font-medium tracking-[0.16em] text-blue-200 uppercase"
        >
          {{ brand.eyebrow }}
        </p>
        <h1 class="mt-5 text-5xl font-semibold leading-[1.08] tracking-tight">
          {{ brand.title }}
        </h1>
        <p class="mt-6 max-w-lg text-lg leading-8 text-blue-100">
          {{ brand.description }}
        </p>
        <ul class="mt-10 space-y-4">
          <li
            v-for="benefit in brand.benefits"
            :key="benefit"
            class="flex items-start gap-3 text-[15px] leading-6 text-blue-50"
          >
            <span
              class="i-lucide-check-circle-2 mt-0.5 size-5 shrink-0 text-[#8DB7FF]"
            />
            <span>{{ benefit }}</span>
          </li>
        </ul>
      </div>
      <p class="relative z-10 text-sm text-blue-200">{{ brand.company }}</p>
    </section>

    <section
      class="flex items-center justify-center px-6 py-12 sm:px-10 lg:px-16"
    >
      <div class="w-full max-w-md motion-safe:animate-fade-in-up">
        <div class="flex items-center gap-3 lg:hidden">
          <AlvoradaWordmark />
        </div>
        <p
          class="mt-10 text-sm font-semibold tracking-[0.14em] text-[#2764CF] uppercase"
        >
          {{ brand.platform }}
        </p>
        <AlvoradaWordmark class="mt-4" />
        <h2 class="mt-3 text-4xl font-semibold tracking-tight text-[#132343]">
          {{ brand.loginTitle }}
        </h2>
        <p class="mt-3 text-base leading-7 text-[#64748B]">
          {{ brand.loginDescription }}
        </p>
        <p v-if="showSignupLink" class="mt-3 text-sm text-n-slate-11">
          {{ $t('COMMON.OR') }}
          <router-link to="auth/signup" class="text-link text-n-brand">
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
          class="p-7 mt-9 bg-white border border-[#E2E8F0] rounded-2xl shadow-xl shadow-slate-900/[0.05] sm:p-9"
          :class="{ 'animate-wiggle': loginApi.hasErrored }"
        >
          <div v-if="!email">
            <div v-if="showGoogleOAuth" class="flex flex-col gap-4">
              <GoogleOAuthButton />
              <SimpleDivider :label="$t('COMMON.OR')" class="uppercase" />
            </div>
            <form class="mt-6 space-y-5" @submit.prevent="submitFormLogin">
              <FormInput
                v-model="credentials.email"
                class="!rounded-xl !bg-[#F5F7FB] !px-4 !py-3.5 !text-[#132343] !outline-[#D7DFEC] placeholder:!text-[#93A1B8] focus:!outline-[#1E5ED8] dark:!bg-[#F5F7FB] dark:!text-[#132343]"
                label-class="!font-semibold !text-[#1E293B]"
                name="email_address"
                type="text"
                data-testid="email_input"
                :tabindex="1"
                required
                :label="$t('LOGIN.EMAIL.LABEL')"
                :placeholder="$t('LOGIN.EMAIL.PLACEHOLDER')"
                :has-error="v$.credentials.email.$error"
                @input="v$.credentials.email.$touch"
              />
              <FormInput
                v-model="credentials.password"
                class="!rounded-xl !bg-[#F5F7FB] !px-4 !py-3.5 !text-[#132343] !outline-[#D7DFEC] placeholder:!text-[#93A1B8] focus:!outline-[#1E5ED8] dark:!bg-[#F5F7FB] dark:!text-[#132343]"
                label-class="!font-semibold !text-[#1E293B]"
                type="password"
                name="password"
                data-testid="password_input"
                required
                :tabindex="2"
                :label="$t('LOGIN.PASSWORD.LABEL')"
                :placeholder="$t('LOGIN.PASSWORD.PLACEHOLDER')"
                :has-error="v$.credentials.password.$error"
                @input="v$.credentials.password.$touch"
              >
                <p v-if="!globalConfig.disableUserProfileUpdate">
                  <router-link
                    to="auth/reset/password"
                    class="text-sm font-medium text-[#1E5ED8] hover:text-[#0C327F]"
                    tabindex="4"
                  >
                    {{ $t('LOGIN.FORGOT_PASSWORD') }}
                  </router-link>
                </p>
              </FormInput>
              <NextButton
                lg
                type="submit"
                data-testid="submit_button"
                class="!mt-7 !w-full !rounded-xl !bg-[#1557D6] !py-3.5 !text-base hover:!bg-[#0D46B3]"
                :tabindex="3"
                :label="$t('LOGIN.SUBMIT')"
                :disabled="loginApi.showLoading"
                :is-loading="loginApi.showLoading"
              />
            </form>
            <p class="mt-6 text-center text-xs leading-5 text-[#94A3B8]">
              {{ brand.security }}
            </p>
          </div>
          <div v-else class="flex items-center justify-center py-8">
            <Spinner color-scheme="primary" size="" />
          </div>
        </section>
      </div>
    </section>
  </main>
</template>
