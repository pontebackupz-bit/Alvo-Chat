<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { BaseTable } from 'dashboard/components-next/table';
import Button from 'dashboard/components-next/button/Button.vue';
import crmAPI from 'dashboard/api/crm';
import CrmPageHeader from './CrmPageHeader.vue';

const { t } = useI18n();
const route = useRoute();
const accountId = computed(() => route.params.accountId);
const rules = ref([]);
const connections = ref([]);
const isLoading = ref(false);
const isSaving = ref(false);
const showModal = ref(false);
const selectedRule = ref(null);
const events = [
  'lead.created',
  'conversation.created',
  'message.received',
  'message.sent',
  'conversation.resolved',
  'contact.created',
  'lead.converted',
  'assignee.changed',
  'conversation.status_changed',
];
const form = ref({
  name: '',
  event_name: 'lead.created',
  n8n_connection_id: '',
  workflow_id: '',
  webhook_path: '',
  active: true,
});
const headers = computed(() => [
  t('CRM.AUTOMATION.NAME'),
  t('CRM.AUTOMATION.EVENT'),
  t('CRM.AUTOMATION.CONNECTION'),
  t('CRM.COMMON.STATUS'),
  t('CRM.COMMON.ACTIONS'),
]);

const fetchData = async () => {
  isLoading.value = true;
  try {
    const [rulesResponse, connectionsResponse] = await Promise.all([
      crmAPI.getAutomationRules(accountId.value),
      crmAPI.getN8nConnections(accountId.value),
    ]);
    rules.value = Array.isArray(rulesResponse.data)
      ? rulesResponse.data
      : rulesResponse.data.automation_rules || [];
    connections.value = Array.isArray(connectionsResponse.data)
      ? connectionsResponse.data
      : connectionsResponse.data.n8n_connections || [];
  } catch (error) {
    useAlert(t('CRM.AUTOMATION.FETCH_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const openCreate = () => {
  selectedRule.value = null;
  form.value = {
    name: '',
    event_name: 'lead.created',
    n8n_connection_id: '',
    workflow_id: '',
    webhook_path: '',
    active: true,
  };
  showModal.value = true;
};

const openEdit = rule => {
  selectedRule.value = rule;
  form.value = {
    name: rule.name,
    event_name: rule.event_name,
    n8n_connection_id: rule.n8n_connection_id,
    workflow_id: rule.workflow_id,
    webhook_path: rule.webhook_path,
    active: rule.active,
  };
  showModal.value = true;
};

const closeModal = () => {
  showModal.value = false;
  selectedRule.value = null;
};

const saveRule = async () => {
  isSaving.value = true;
  const payload = {
    ...form.value,
    n8n_connection_id: Number(form.value.n8n_connection_id),
  };
  try {
    if (selectedRule.value) {
      await crmAPI.updateAutomationRule(
        accountId.value,
        selectedRule.value.id,
        payload
      );
      useAlert(t('CRM.AUTOMATION.UPDATE_SUCCESS'));
    } else {
      await crmAPI.createAutomationRule(accountId.value, payload);
      useAlert(t('CRM.AUTOMATION.CREATE_SUCCESS'));
    }
    closeModal();
    await fetchData();
  } catch (error) {
    useAlert(t('CRM.AUTOMATION.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const deleteRule = async rule => {
  try {
    await crmAPI.deleteAutomationRule(accountId.value, rule.id);
    await fetchData();
    useAlert(t('CRM.AUTOMATION.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(t('CRM.AUTOMATION.SAVE_ERROR'));
  }
};

const connectionName = rule =>
  connections.value.find(connection => connection.id === rule.n8n_connection_id)
    ?.name || `#${rule.n8n_connection_id}`;

onMounted(fetchData);
</script>

<template>
  <section>
    <CrmPageHeader
      :title="$t('CRM.AUTOMATION.TITLE')"
      :description="$t('CRM.AUTOMATION.DESCRIPTION')"
      :action-label="$t('CRM.AUTOMATION.NEW')"
      action-icon="i-lucide-plus"
      @action="openCreate"
    />
    <woot-loading-state v-if="isLoading" :message="$t('CRM.COMMON.LOADING')" />
    <BaseTable
      v-else
      :headers="headers"
      :items="rules"
      :no-data-message="$t('CRM.AUTOMATION.EMPTY')"
    >
      <template #row="{ items }">
        <tr v-for="rule in items" :key="rule.id">
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-12">
            {{ rule.name }}
          </td>
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
            {{ rule.event_name }}
          </td>
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
            {{ connectionName(rule) }}
          </td>
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
            {{
              rule.active ? $t('CRM.COMMON.ACTIVE') : $t('CRM.COMMON.INACTIVE')
            }}
          </td>
          <td class="py-4 text-right">
            <div class="crm-table-actions">
              <Button
                variant="link"
                size="sm"
                :label="$t('CRM.COMMON.EDIT')"
                @click="openEdit(rule)"
              />
              <Button
                variant="link"
                color="ruby"
                size="sm"
                :label="$t('CRM.COMMON.DELETE')"
                @click="deleteRule(rule)"
              />
            </div>
          </td>
        </tr>
      </template>
    </BaseTable>
    <woot-modal v-model:show="showModal" :on-close="closeModal"
      ><form class="crm-modal-form" @submit.prevent="saveRule">
        <woot-modal-header
          :header-title="
            selectedRule
              ? $t('CRM.AUTOMATION.EDIT_TITLE')
              : $t('CRM.AUTOMATION.CREATE_TITLE')
          "
        /><label
          >{{ $t('CRM.AUTOMATION.NAME')
          }}<input v-model.trim="form.name" required /></label
        ><label
          >{{ $t('CRM.AUTOMATION.EVENT')
          }}<select v-model="form.event_name">
            <option v-for="event in events" :key="event" :value="event">
              {{ event }}
            </option>
          </select></label
        ><label
          >{{ $t('CRM.AUTOMATION.CONNECTION')
          }}<select v-model="form.n8n_connection_id" required>
            <option disabled value="">
              {{ $t('CRM.AUTOMATION.CONNECTION') }}
            </option>
            <option
              v-for="connection in connections"
              :key="connection.id"
              :value="connection.id"
            >
              {{ connection.name }}
            </option>
          </select></label
        ><label
          >{{ $t('CRM.AUTOMATION.WORKFLOW')
          }}<input v-model.trim="form.workflow_id" required /></label
        ><label
          >{{ $t('CRM.AUTOMATION.WEBHOOK')
          }}<input
            v-model.trim="form.webhook_path"
            required
            placeholder="crm/new-lead" /></label
        ><label class="crm-form-checkbox"
          ><input v-model="form.active" type="checkbox" />{{
            $t('CRM.COMMON.ACTIVE')
          }}</label
        >
        <div class="crm-form-actions">
          <Button
            variant="faded"
            color="slate"
            :label="$t('CRM.COMMON.CANCEL')"
            type="button"
            @click="closeModal"
          /><Button
            :label="$t('CRM.COMMON.SAVE')"
            :is-loading="isSaving"
            type="submit"
          />
        </div></form
    ></woot-modal>
  </section>
</template>
