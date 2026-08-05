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
const isLoading = ref(false);
const isSaving = ref(false);
const showModal = ref(false);
const selectedRule = ref(null);
const form = ref({
  name: '',
  strategy: 'round_robin',
  priority: 1,
  team_id: '',
  active: true,
});
const headers = computed(() => [
  t('CRM.DISTRIBUTION.NAME'),
  t('CRM.DISTRIBUTION.STRATEGY'),
  t('CRM.DISTRIBUTION.PRIORITY'),
  t('CRM.COMMON.STATUS'),
  t('CRM.COMMON.ACTIONS'),
]);
const strategies = computed(() => [
  { value: 'round_robin', label: t('CRM.DISTRIBUTION.ROUND_ROBIN') },
  {
    value: 'least_open_conversations',
    label: t('CRM.DISTRIBUTION.LEAST_OPEN'),
  },
]);
const fetchRules = async () => {
  isLoading.value = true;
  try {
    const { data } = await crmAPI.getDistributionRules(accountId.value);
    rules.value = Array.isArray(data) ? data : data.distribution_rules || [];
  } catch (error) {
    useAlert(t('CRM.DISTRIBUTION.FETCH_ERROR'));
  } finally {
    isLoading.value = false;
  }
};
const openCreate = () => {
  selectedRule.value = null;
  form.value = {
    name: '',
    strategy: 'round_robin',
    priority: 1,
    team_id: '',
    active: true,
  };
  showModal.value = true;
};
const openEdit = rule => {
  selectedRule.value = rule;
  form.value = {
    name: rule.name,
    strategy: rule.strategy,
    priority: rule.priority,
    team_id: rule.team_id || '',
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
    priority: Number(form.value.priority),
    team_id: form.value.team_id ? Number(form.value.team_id) : null,
  };
  try {
    if (selectedRule.value) {
      await crmAPI.updateDistributionRule(
        accountId.value,
        selectedRule.value.id,
        payload
      );
      useAlert(t('CRM.DISTRIBUTION.UPDATE_SUCCESS'));
    } else {
      await crmAPI.createDistributionRule(accountId.value, payload);
      useAlert(t('CRM.DISTRIBUTION.CREATE_SUCCESS'));
    }
    closeModal();
    await fetchRules();
  } catch (error) {
    useAlert(t('CRM.DISTRIBUTION.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};
const deleteRule = async rule => {
  try {
    await crmAPI.deleteDistributionRule(accountId.value, rule.id);
    await fetchRules();
    useAlert(t('CRM.DISTRIBUTION.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(t('CRM.DISTRIBUTION.SAVE_ERROR'));
  }
};
const strategyLabel = strategy =>
  strategies.value.find(item => item.value === strategy)?.label || strategy;
onMounted(fetchRules);
</script>

<template>
  <section>
    <CrmPageHeader
      :title="$t('CRM.DISTRIBUTION.TITLE')"
      :description="$t('CRM.DISTRIBUTION.DESCRIPTION')"
      :action-label="$t('CRM.DISTRIBUTION.NEW')"
      action-icon="i-lucide-plus"
      @action="openCreate"
    />
    <woot-loading-state v-if="isLoading" :message="$t('CRM.COMMON.LOADING')" />
    <BaseTable
      v-else
      :headers="headers"
      :items="rules"
      :no-data-message="$t('CRM.DISTRIBUTION.EMPTY')"
      ><template #row="{ items }"
        ><tr v-for="rule in items" :key="rule.id">
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-12">
            {{ rule.name }}
          </td>
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
            {{ strategyLabel(rule.strategy) }}
          </td>
          <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
            {{ rule.priority }}
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
          </td></tr></template
    ></BaseTable>
    <woot-modal v-model:show="showModal" :on-close="closeModal"
      ><form class="crm-modal-form" @submit.prevent="saveRule">
        <woot-modal-header
          :header-title="
            selectedRule
              ? $t('CRM.DISTRIBUTION.EDIT_TITLE')
              : $t('CRM.DISTRIBUTION.CREATE_TITLE')
          "
        /><label
          >{{ $t('CRM.DISTRIBUTION.NAME')
          }}<input v-model.trim="form.name" required /></label
        ><label
          >{{ $t('CRM.DISTRIBUTION.STRATEGY')
          }}<select v-model="form.strategy">
            <option
              v-for="strategy in strategies"
              :key="strategy.value"
              :value="strategy.value"
            >
              {{ strategy.label }}
            </option>
          </select></label
        ><label
          >{{ $t('CRM.DISTRIBUTION.PRIORITY')
          }}<input
            v-model="form.priority"
            required
            type="number"
            min="1" /></label
        ><label
          >{{ $t('CRM.DISTRIBUTION.TEAM')
          }}<input v-model="form.team_id" type="number" min="1" /></label
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
