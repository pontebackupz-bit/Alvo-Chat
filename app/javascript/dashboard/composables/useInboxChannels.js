// The channels a new inbox can use, shared by the inbox wizard and the
// AlvoChat "Conexões" page.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';

export function useInboxChannels() {
  const { t } = useI18n();
  const { currentAccount } = useAccount();
  const globalConfig = useMapGetter('globalConfig/get');

  const enabledFeatures = computed(() => currentAccount.value?.features || {});

  const hasTiktokConfigured = computed(() => {
    return window.chatwootConfig?.tiktokAppId;
  });

  const channelList = computed(() => {
    const { apiChannelName } = globalConfig.value;
    const channels = [
      {
        key: 'website',
        title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WEBSITE.TITLE'),
        description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WEBSITE.DESCRIPTION'),
        icon: 'i-woot-website',
      },
      {
        key: 'facebook',
        title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.FACEBOOK.TITLE'),
        description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.FACEBOOK.DESCRIPTION'),
        icon: 'i-woot-messenger',
      },
      {
        key: 'whatsapp',
        title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WHATSAPP.TITLE'),
        description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WHATSAPP.DESCRIPTION'),
        icon: 'i-woot-whatsapp',
      },
      {
        key: 'sms',
        title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.SMS.TITLE'),
        description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.SMS.DESCRIPTION'),
        icon: 'i-woot-sms',
      },
      {
        key: 'email',
        title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.EMAIL.TITLE'),
        description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.EMAIL.DESCRIPTION'),
        icon: 'i-woot-mail',
      },
      {
        key: 'api',
        title: apiChannelName || t('INBOX_MGMT.ADD.AUTH.CHANNEL.API.TITLE'),
        description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.API.DESCRIPTION'),
        icon: 'i-woot-api',
      },
      {
        key: 'telegram',
        title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.TELEGRAM.TITLE'),
        description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.TELEGRAM.DESCRIPTION'),
        icon: 'i-woot-telegram',
      },
      {
        key: 'line',
        title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.LINE.TITLE'),
        description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.LINE.DESCRIPTION'),
        icon: 'i-woot-line',
      },
      {
        key: 'instagram',
        title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.INSTAGRAM.TITLE'),
        description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.INSTAGRAM.DESCRIPTION'),
        icon: 'i-woot-instagram',
      },
    ];

    if (hasTiktokConfigured.value) {
      channels.push({
        key: 'tiktok',
        title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.TIKTOK.TITLE'),
        description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.TIKTOK.DESCRIPTION'),
        icon: 'i-woot-tiktok',
      });
    }

    channels.push({
      key: 'voice',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.VOICE.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.VOICE.DESCRIPTION'),
      icon: 'i-woot-voice',
    });

    channels.push({
      key: 'whatsapp_call',
      title: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WHATSAPP_CALL.TITLE'),
      description: t('INBOX_MGMT.ADD.AUTH.CHANNEL.WHATSAPP_CALL.DESCRIPTION'),
      icon: 'i-woot-whatsapp',
    });

    return channels;
  });

  return { channelList, enabledFeatures };
}
