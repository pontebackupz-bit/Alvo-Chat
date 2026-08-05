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
const leads = ref([]);
const isLoading = ref(false);
const isSaving = ref(false);
const showModal = ref(false);
const selectedLead = ref(null);
const form = ref({ contact_id: '', stage: 'new_lead', value: '' });

const stages = computed(() => [
  'new_lead',
  'qualified',
  'proposal',
  'won',
  'lost',
]);
const headers = computed(() => [
  t('CRM.LEADS.CONTACT'),
  t('CRM.LEADS.STAGE'),
  t('CRM.LEADS.VALUE'),
  t('CRM.LEADS.OWNER'),
  t('CRM.LEADS.CREATED'),
  t('CRM.COMMON.ACTIONS'),
]);

const fetchLeads = async () => {
  isLoading.value = true;
  try {
    const { data } = await crmAPI.getLeads(accountId.value);
    leads.value = Array.isArray(data) ? data : data.leads || [];
  } catch (error) {
    useAlert(t('CRM.LEADS.FETCH_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const openCreate = () => {
  selectedLead.value = null;
  form.value = { contact_id: '', stage: 'new_lead', value: '' };
  showModal.value = true;
};

const openEdit = lead => {
  selectedLead.value = lead;
  form.value = {
    contact_id: lead.contact_id,
    stage: lead.stage,
    value: lead.value || '',
  };
  showModal.value = true;
};

const closeModal = () => {
  showModal.value = false;
  selectedLead.value = null;
};

const saveLead = async () => {
  isSaving.value = true;
  const payload = { ...form.value, value: Number(form.value.value || 0) };
  try {
    if (selectedLead.value) {
      await crmAPI.updateLead(accountId.value, selectedLead.value.id, payload);
      useAlert(t('CRM.LEADS.UPDATE_SUCCESS'));
    } else {
      await crmAPI.createLead(accountId.value, payload);
      useAlert(t('CRM.LEADS.CREATE_SUCCESS'));
    }
    closeModal();
    await fetchLeads();
  } catch (error) {
    useAlert(t('CRM.LEADS.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const stageLabel = stage => t(`CRM.LEADS.STAGES.${stage.toUpperCase()}`);
const formatValue = value =>
  new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: 'BRL',
  }).format(value || 0);
const formatDate = value =>
  new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(
    new Date(value)
  );

onMounted(fetchLeads);
</script>

<template>
  <section>
    <CrmPageHeader
      :title="$t('CRM.LEADS.TITLE')"
      :description="$t('CRM.LEADS.DESCRIPTION')"
      :action-label="$t('CRM.LEADS.NEW')"
      action-icon="i-lucide-plus"
      @action="openCreate"
    />
    <woot-loading-state v-if="isLoading" :message="$t('CRM.COMMON.LOADING')" />
    <BaseTable
      v-else
      :headers="headers"
      :items="leads"
      :no-data-message="$t('CRM.LEADS.EMPTY')"
    >
      <template #row="{ items }">
        <tr v-for="lead in items" :key="lead.id">
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-12">
            #{{ lead.contact_id }}
          </td>
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
            {{ stageLabel(lead.stage) }}
          </td>
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
            {{ formatValue(lead.value) }}
          </td>
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
            {{ lead.owner_id ? `#${lead.owner_id}` : '—' }}
          </td>
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
            {{ formatDate(lead.created_at) }}
          </td>
          <td class="py-4 text-right">
            <div class="crm-table-actions">
              <Button
                variant="link"
                size="sm"
                :label="$t('CRM.COMMON.EDIT')"
                @click="openEdit(lead)"
              />
            </div>
          </td>
        </tr>
      </template>
    </BaseTable>

    <woot-modal v-model:show="showModal" :on-close="closeModal">
      <form class="crm-modal-form" @submit.prevent="saveLead">
        <woot-modal-header
          :header-title="
            selectedLead
              ? $t('CRM.LEADS.EDIT_TITLE')
              : $t('CRM.LEADS.CREATE_TITLE')
          "
        />
        <label
          >{{ $t('CRM.LEADS.CONTACT')
          }}<input v-model="form.contact_id" required type="number" min="1"
        /></label>
        <label
          >{{ $t('CRM.LEADS.STAGE')
          }}<select v-model="form.stage">
            <option v-for="stage in stages" :key="stage" :value="stage">
              {{ stageLabel(stage) }}
            </option>
          </select></label
        >
        <label
          >{{ $t('CRM.LEADS.VALUE')
          }}<input v-model="form.value" type="number" min="0" step="0.01"
        /></label>
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
        </div>
      </form>
    </woot-modal>
  </section>
</template>
