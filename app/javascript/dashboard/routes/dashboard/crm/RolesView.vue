<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { BaseTable } from 'dashboard/components-next/table';
import Button from 'dashboard/components-next/button/Button.vue';
import crmAPI from 'dashboard/api/crm';
import agentsAPI from 'dashboard/api/agents';
import teamsAPI from 'dashboard/api/teams';
import inboxesAPI from 'dashboard/api/inboxes';
import CrmPageHeader from './CrmPageHeader.vue';

const { t } = useI18n();
const route = useRoute();
const accountId = computed(() => route.params.accountId);
const roles = ref([]);
const supervisors = ref([]);
const assignments = ref([]);
const agents = ref([]);
const teams = ref([]);
const inboxes = ref([]);
const users = ref([]);
const userCounts = ref({});
const isLoading = ref(false);
const isSaving = ref(false);
const isCreatingUser = ref(false);
const showModal = ref(false);
const showAssignmentModal = ref(false);
const showUserModal = ref(false);
const showPasswordModal = ref(false);
const temporaryPassword = ref('');
const form = ref({ user_id: '', team_id: '' });
const assignmentForm = ref({ user_id: '', role_id: '' });
const userForm = ref({
  name: '',
  email: '',
  native_role: 'agent',
  role_id: '',
  team_ids: [],
  inbox_ids: [],
  supervised_team_ids: [],
});
const userHeaders = computed(() => [
  t('CRM.ACCESS.USER'),
  t('CRM.ACCESS.ROLE'),
  t('CRM.ACCESS.TEAM'),
  t('CRM.ACCESS.STATUS'),
  t('CRM.COMMON.ACTIONS'),
]);
const headers = computed(() => [
  t('CRM.ACCESS.USER'),
  t('CRM.ACCESS.TEAM'),
  t('CRM.COMMON.ACTIONS'),
]);
const assignmentHeaders = computed(() => [
  t('CRM.ACCESS.USER'),
  t('CRM.ACCESS.ROLE'),
  t('CRM.COMMON.ACTIONS'),
]);
const supervisorRoleId = computed(
  () => roles.value.find(role => role.key === 'supervisor')?.id
);
const supervisorUserIds = computed(() =>
  assignments.value
    .filter(assignment => assignment.role_id === supervisorRoleId.value)
    .map(assignment => assignment.user_id)
);
const supervisorAgents = computed(() =>
  agents.value.filter(agent => supervisorUserIds.value.includes(agent.id))
);
const isSupervisorRole = roleId => Number(roleId) === supervisorRoleId.value;
const availableCrmRoles = computed(() =>
  roles.value.filter(
    role => userForm.value.native_role === 'administrator' || role.key !== 'administrator'
  )
);

const agentLabel = agent =>
  agent ? `${agent.name || agent.available_name} — ${agent.email}` : '';
const agentName = userId => {
  const agent = agents.value.find(item => item.id === userId);
  return agent ? agentLabel(agent) : `#${userId}`;
};
const teamName = teamId => {
  const team = teams.value.find(item => item.id === teamId);
  return team ? team.name : `#${teamId}`;
};

const fetchData = async () => {
  isLoading.value = true;
  try {
    const [
      rolesResponse,
      supervisorsResponse,
      assignmentsResponse,
      agentsResponse,
      teamsResponse,
      inboxesResponse,
      usersResponse,
    ] = await Promise.all([
      crmAPI.getRoles(accountId.value),
      crmAPI.getTeamSupervisors(accountId.value),
      crmAPI.getRoleAssignments(accountId.value),
      agentsAPI.get(),
      teamsAPI.get(),
      inboxesAPI.get(),
      crmAPI.getUsers(accountId.value),
    ]);
    roles.value = Array.isArray(rolesResponse.data)
      ? rolesResponse.data
      : rolesResponse.data.roles || [];
    supervisors.value = Array.isArray(supervisorsResponse.data)
      ? supervisorsResponse.data
      : supervisorsResponse.data.team_supervisors || [];
    assignments.value = Array.isArray(assignmentsResponse.data)
      ? assignmentsResponse.data
      : assignmentsResponse.data.role_assignments || [];
    agents.value = Array.isArray(agentsResponse.data)
      ? agentsResponse.data
      : [];
    teams.value = Array.isArray(teamsResponse.data) ? teamsResponse.data : [];
    inboxes.value = Array.isArray(inboxesResponse.data) ? inboxesResponse.data : [];
    users.value = usersResponse.data.users || [];
    userCounts.value = usersResponse.data.counts || {};
  } catch (error) {
    useAlert(t('CRM.ACCESS.FETCH_ERROR'));
  } finally {
    isLoading.value = false;
  }
};
const closeModal = () => {
  showModal.value = false;
  form.value = { user_id: '', team_id: '' };
};
const saveSupervisor = async () => {
  isSaving.value = true;
  try {
    await crmAPI.assignTeamSupervisor(accountId.value, {
      user_id: Number(form.value.user_id),
      team_id: Number(form.value.team_id),
    });
    closeModal();
    await fetchData();
    useAlert(t('CRM.ACCESS.CREATE_SUCCESS'));
  } catch (error) {
    useAlert(t('CRM.ACCESS.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};
const deleteSupervisor = async supervisor => {
  try {
    await crmAPI.deleteTeamSupervisor(accountId.value, supervisor.id);
    await fetchData();
    useAlert(t('CRM.ACCESS.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(t('CRM.ACCESS.SAVE_ERROR'));
  }
};
const closeAssignmentModal = () => {
  showAssignmentModal.value = false;
  assignmentForm.value = { user_id: '', role_id: '' };
};
const openUserModal = () => {
  userForm.value = {
    name: '',
    email: '',
    native_role: 'agent',
    role_id: roles.value.find(role => role.key === 'seller')?.id || '',
    team_ids: [],
    inbox_ids: [],
    supervised_team_ids: [],
  };
  showUserModal.value = true;
};
const closeUserModal = () => {
  showUserModal.value = false;
};
const createUser = async () => {
  isCreatingUser.value = true;

  try {
    const response = await crmAPI.createUser(accountId.value, {
      name: userForm.value.name,
      email: userForm.value.email,
      native_role: userForm.value.native_role,
      crm_role_id: Number(userForm.value.role_id),
      team_ids: userForm.value.team_ids.map(Number),
      inbox_ids: userForm.value.inbox_ids.map(Number),
      supervised_team_ids: userForm.value.supervised_team_ids.map(Number),
    });
    temporaryPassword.value = response.data.temporary_password || '';
    closeUserModal();
    await fetchData();
    useAlert(t('CRM.ACCESS.USER_CREATE_SUCCESS'));
    showPasswordModal.value = temporaryPassword.value !== '';
  } catch (error) {
    useAlert(t('CRM.ACCESS.USER_CREATE_ERROR'));
  } finally {
    isCreatingUser.value = false;
  }
};
const resetPassword = async user => {
  try {
    const response = await crmAPI.resetUserPassword(accountId.value, user.id);
    temporaryPassword.value = response.data.temporary_password;
    showPasswordModal.value = true;
    useAlert(t('CRM.ACCESS.PASSWORD_RESET_SUCCESS'));
  } catch (error) {
    useAlert(t('CRM.ACCESS.PASSWORD_RESET_ERROR'));
  }
};
const userRoleName = user =>
  roles.value.find(role => role.id === user.crm_role_id)?.name || '—';
const userTeamNames = user =>
  teams.value.filter(team => user.team_ids.includes(team.id)).map(team => team.name).join(', ') || '—';
const availabilityLabel = availability =>
  t(`CRM.ACCESS.${availability.toUpperCase()}`);
const copyTemporaryPassword = async () => {
  await navigator.clipboard.writeText(temporaryPassword.value);
  useAlert(t('CRM.ACCESS.PASSWORD_COPIED'));
};
const closePasswordModal = () => {
  showPasswordModal.value = false;
  temporaryPassword.value = '';
};
const saveAssignment = async () => {
  isSaving.value = true;
  try {
    await crmAPI.createRoleAssignment(accountId.value, {
      user_id: Number(assignmentForm.value.user_id),
      role_id: Number(assignmentForm.value.role_id),
    });
    closeAssignmentModal();
    await fetchData();
    useAlert(t('CRM.ACCESS.ASSIGNMENT_SUCCESS'));
  } catch (error) {
    useAlert(t('CRM.ACCESS.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};
const deleteAssignment = async assignment => {
  try {
    await crmAPI.deleteRoleAssignment(accountId.value, assignment.id);
    await fetchData();
    useAlert(t('CRM.ACCESS.ASSIGNMENT_DELETE_SUCCESS'));
  } catch (error) {
    useAlert(t('CRM.ACCESS.SAVE_ERROR'));
  }
};
const roleName = assignment =>
  roles.value.find(role => role.id === assignment.role_id)?.name ||
  `#${assignment.role_id}`;
const permissions = role => role.permissions || [];
onMounted(fetchData);
</script>

<template>
  <section>
    <CrmPageHeader
      :title="$t('CRM.ACCESS.TITLE')"
      :description="$t('CRM.ACCESS.DESCRIPTION')"
      :action-label="$t('CRM.ACCESS.NEW_USER')"
      action-icon="i-lucide-user-plus"
      @action="openUserModal"
    />
    <woot-loading-state v-if="isLoading" :message="$t('CRM.COMMON.LOADING')" />
    <template v-else>
      <div class="grid gap-4 md:grid-cols-3">
        <article class="rounded-xl border border-n-weak p-4">
          <p class="text-sm text-n-slate-11">{{ $t('CRM.ACCESS.ALL_USERS') }}</p>
          <p class="mt-1 text-2xl font-semibold text-n-slate-12">{{ users.length }}</p>
        </article>
        <article class="rounded-xl border border-n-weak p-4">
          <p class="text-sm text-n-slate-11">{{ $t('CRM.ACCESS.ONLINE_USERS') }}</p>
          <p class="mt-1 text-2xl font-semibold text-n-slate-12">{{ userCounts.online || 0 }}</p>
        </article>
        <article class="rounded-xl border border-n-weak p-4">
          <p class="text-sm text-n-slate-11">{{ $t('CRM.ACCESS.BUSY') }}</p>
          <p class="mt-1 text-2xl font-semibold text-n-slate-12">{{ userCounts.busy || 0 }}</p>
        </article>
      </div>
      <div class="mt-8">
        <h2 class="text-heading-3 text-n-slate-12">{{ $t('CRM.ACCESS.USERS') }}</h2>
        <p class="mt-1 text-sm text-n-slate-11">{{ $t('CRM.ACCESS.USERS_DESCRIPTION') }}</p>
        <BaseTable class="mt-3" :headers="userHeaders" :items="users" :no-data-message="$t('CRM.COMMON.NO_RESULTS')">
          <template #row="{ items }">
            <tr v-for="user in items" :key="user.id">
              <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-12">
                <div>{{ user.name }}</div>
                <div class="text-sm text-n-slate-11">{{ user.email }}</div>
              </td>
              <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">{{ userRoleName(user) }}</td>
              <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">{{ userTeamNames(user) }}</td>
              <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
                <span class="inline-flex items-center gap-2"><span class="size-2 rounded-full" :class="user.availability === 'online' ? 'bg-n-teal-10' : user.availability === 'busy' ? 'bg-n-amber-10' : 'bg-n-slate-9'" />{{ availabilityLabel(user.availability) }}</span>
              </td>
              <td class="py-4 text-right">
                <Button variant="link" size="sm" :label="$t('CRM.ACCESS.PASSWORD_RESET')" @click="resetPassword(user)" />
              </td>
            </tr>
          </template>
        </BaseTable>
      </div>
      <div class="mt-6">
        <h2 class="text-heading-3 text-n-slate-12">
          {{ $t('CRM.ACCESS.ROLES') }}
        </h2>
        <div class="grid gap-4 mt-4 md:grid-cols-2 xl:grid-cols-3">
          <article
            v-for="role in roles"
            :key="role.id"
            class="p-4 border rounded-xl border-n-weak"
          >
            <h3 class="text-heading-3 text-n-slate-12">{{ role.name }}</h3>
            <p class="mt-1 text-sm text-n-slate-11">{{ role.key }}</p>
            <ul class="mt-4 space-y-2 text-sm text-n-slate-11">
              <li
                v-for="permission in permissions(role)"
                :key="permission.id || permission.key"
                class="flex gap-2"
              >
                <span class="text-n-brand">•</span
                >{{ permission.name || permission.key }}
              </li>
              <li v-if="!permissions(role).length">—</li>
            </ul>
          </article>
        </div>
      </div>
      <div class="mt-8">
        <div class="flex items-center justify-between gap-4">
          <h2 class="text-heading-3 text-n-slate-12">
            {{ $t('CRM.ACCESS.ASSIGNMENTS') }}
          </h2>
          <Button
            size="sm"
            :label="$t('CRM.ACCESS.ASSIGN_ROLE')"
            icon="i-lucide-user-round-plus"
            @click="showAssignmentModal = true"
          />
        </div>
        <BaseTable
          class="mt-3"
          :headers="assignmentHeaders"
          :items="assignments"
          :no-data-message="$t('CRM.COMMON.NO_RESULTS')"
          ><template #row="{ items }"
            ><tr v-for="assignment in items" :key="assignment.id">
              <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-12">
                {{ agentName(assignment.user_id) }}
              </td>
              <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
                {{ roleName(assignment) }}
              </td>
              <td class="py-4 text-right">
                <div class="crm-table-actions">
                  <Button
                    variant="link"
                    color="ruby"
                    size="sm"
                    :label="$t('CRM.COMMON.DELETE')"
                    @click="deleteAssignment(assignment)"
                  />
                </div>
              </td></tr></template
        ></BaseTable>
      </div>
      <div class="mt-8">
        <div class="flex items-center justify-between gap-4">
          <h2 class="text-heading-3 text-n-slate-12">
            {{ $t('CRM.ACCESS.SUPERVISORS') }}
          </h2>
          <Button
            size="sm"
            :label="$t('CRM.ACCESS.NEW')"
            icon="i-lucide-user-plus"
            @click="showModal = true"
          />
        </div>
        <BaseTable
          class="mt-3"
          :headers="headers"
          :items="supervisors"
          :no-data-message="$t('CRM.ACCESS.EMPTY')"
          ><template #row="{ items }"
            ><tr v-for="supervisor in items" :key="supervisor.id">
              <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-12">
                {{ agentName(supervisor.user_id) }}
              </td>
              <td class="py-4 ltr:pr-4 rtl:pl-4 text-body-main text-n-slate-11">
                {{ teamName(supervisor.team_id) }}
              </td>
              <td class="py-4 text-right">
                <div class="crm-table-actions">
                  <Button
                    variant="link"
                    color="ruby"
                    size="sm"
                    :label="$t('CRM.COMMON.DELETE')"
                    @click="deleteSupervisor(supervisor)"
                  />
                </div>
              </td></tr></template
        ></BaseTable>
      </div>
    </template>
    <woot-modal v-model:show="showUserModal" :on-close="closeUserModal">
      <form class="crm-modal-form" @submit.prevent="createUser">
        <woot-modal-header
          :header-title="$t('CRM.ACCESS.USER_CREATE_TITLE')"
          :header-content="$t('CRM.ACCESS.USER_CREATE_DESCRIPTION')"
        />
        <label
          >{{ $t('CRM.ACCESS.USER_NAME')
          }}<input
            v-model.trim="userForm.name"
            required
            type="text"
            autocomplete="name"
            :aria-label="$t('CRM.ACCESS.USER_NAME')"
          />
        </label>
        <label
          >{{ $t('CRM.ACCESS.USER_EMAIL')
          }}<input
            v-model.trim="userForm.email"
            required
            type="email"
            autocomplete="email"
            :aria-label="$t('CRM.ACCESS.USER_EMAIL')"
          />
        </label>
        <label
          >{{ $t('CRM.ACCESS.NATIVE_ROLE')
          }}<select v-model="userForm.native_role" required>
            <option value="agent">{{ $t('CRM.ACCESS.NATIVE_AGENT') }}</option>
            <option value="administrator">
              {{ $t('CRM.ACCESS.NATIVE_ADMINISTRATOR') }}
            </option>
          </select></label
        >
        <label
          >{{ $t('CRM.ACCESS.ROLE')
          }}<select v-model="userForm.role_id" required>
            <option disabled value="">
              {{ $t('CRM.ACCESS.SELECT_ROLE') }}
            </option>
            <option v-for="role in availableCrmRoles" :key="role.id" :value="role.id">
              {{ role.name }}
            </option>
          </select></label
        >
        <label
          >{{ $t('CRM.ACCESS.TEAM_OPTIONAL')
          }}<select v-model="userForm.team_ids" multiple>
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ team.name }}
            </option>
          </select></label
        >
        <label
          >{{ $t('CRM.ACCESS.INBOXES')
          }}<select v-model="userForm.inbox_ids" multiple required>
            <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
              {{ inbox.name }}
            </option>
          </select></label
        >
        <label v-if="isSupervisorRole(userForm.role_id)"
          >{{ $t('CRM.ACCESS.SUPERVISED_TEAMS')
          }}<select v-model="userForm.supervised_team_ids" multiple>
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ team.name }}
            </option>
          </select></label
        >
        <p class="crm-form-help">
          {{ $t('CRM.ACCESS.TEAM_HELP') }}
        </p>
        <div class="crm-form-actions">
          <Button
            variant="faded"
            color="slate"
            :label="$t('CRM.COMMON.CANCEL')"
            type="button"
            @click="closeUserModal"
          />
          <Button
            :label="$t('CRM.ACCESS.CREATE_USER')"
            :is-loading="isCreatingUser"
            type="submit"
          />
        </div>
      </form>
    </woot-modal>
    <woot-modal v-model:show="showPasswordModal" :on-close="closePasswordModal">
      <div class="p-6">
        <woot-modal-header :header-title="$t('CRM.ACCESS.TEMPORARY_PASSWORD')" />
        <p class="mt-2 text-sm text-n-slate-11">{{ $t('CRM.ACCESS.TEMPORARY_PASSWORD_HELP') }}</p>
        <code class="mt-4 block rounded-lg bg-n-slate-3 p-3 text-base text-n-slate-12 break-all">{{ temporaryPassword }}</code>
        <div class="mt-4 flex justify-end">
          <Button :label="$t('CRM.ACCESS.COPY_PASSWORD')" icon="i-lucide-copy" @click="copyTemporaryPassword" />
        </div>
      </div>
    </woot-modal>
    <woot-modal v-model:show="showModal" :on-close="closeModal">
      <form class="crm-modal-form" @submit.prevent="saveSupervisor">
        <woot-modal-header :header-title="$t('CRM.ACCESS.CREATE_TITLE')" />
        <p class="crm-form-help">
          {{ $t('CRM.ACCESS.SUPERVISOR_HELP') }}
        </p>
        <label
          >{{ $t('CRM.ACCESS.USER')
          }}<select
            v-model="form.user_id"
            required
            :disabled="!supervisorAgents.length"
          >
            <option disabled value="">
              {{ $t('CRM.ACCESS.SELECT_SUPERVISOR') }}
            </option>
            <option
              v-for="agent in supervisorAgents"
              :key="agent.id"
              :value="agent.id"
            >
              {{ agentLabel(agent) }}
            </option>
          </select></label
        ><label
          >{{ $t('CRM.ACCESS.TEAM')
          }}<select v-model="form.team_id" required>
            <option disabled value="">
              {{ $t('CRM.ACCESS.SELECT_TEAM') }}
            </option>
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ team.name }}
            </option>
          </select></label
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
        </div>
      </form>
    </woot-modal>
    <woot-modal
      v-model:show="showAssignmentModal"
      :on-close="closeAssignmentModal"
    >
      <form class="crm-modal-form" @submit.prevent="saveAssignment">
        <woot-modal-header :header-title="$t('CRM.ACCESS.ASSIGN_ROLE')" />
        <label
          >{{ $t('CRM.ACCESS.USER')
          }}<select v-model="assignmentForm.user_id" required>
            <option disabled value="">
              {{ $t('CRM.ACCESS.SELECT_USER') }}
            </option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agentLabel(agent) }}
            </option>
          </select></label
        >
        <label
          >{{ $t('CRM.ACCESS.ROLE')
          }}<select v-model="assignmentForm.role_id" required>
            <option disabled value="">{{ $t('CRM.ACCESS.ROLE') }}</option>
            <option v-for="role in roles" :key="role.id" :value="role.id">
              {{ role.name }}
            </option>
          </select></label
        >
        <div class="crm-form-actions">
          <Button
            variant="faded"
            color="slate"
            :label="$t('CRM.COMMON.CANCEL')"
            type="button"
            @click="closeAssignmentModal"
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
