<script setup>
import { useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import { useInboxChannels } from 'dashboard/composables/useInboxChannels';

import ChannelItem from 'dashboard/components/widgets/ChannelItem.vue';

const router = useRouter();
const { accountId } = useAccount();

const { channelList, enabledFeatures } = useInboxChannels();

const initChannelAuth = channel => {
  const params = {
    sub_page: channel,
    accountId: accountId.value,
  };
  router.push({ name: 'settings_inboxes_page_channel', params });
};
</script>

<template>
  <div
    class="grid max-w-3xl grid-cols-1 xs:grid-cols-2 mx-0 gap-6 sm:grid-cols-3 p-8"
  >
    <ChannelItem
      v-for="channel in channelList"
      :key="channel.key"
      :channel="channel"
      :enabled-features="enabledFeatures"
      @channel-item-click="initChannelAuth"
    />
  </div>
</template>
