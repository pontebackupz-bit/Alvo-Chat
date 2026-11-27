# The downloaded agent report lists the attending agents only: administrators
# manage the account and are left out, as on the reports screens.
module OmnichannelCrm::AgentReportsWithoutAdministrators
  def generate_agents_report
    reports = V2::Reports::AgentSummaryBuilder.new(
      account: Current.account,
      params: build_params(type: :agent)
    ).build

    administrators = Current.account.account_users.administrator.select(:user_id)
    Current.account.users.where.not(id: administrators).map do |agent|
      report = reports.find { |r| r[:id] == agent.id }
      [agent.name] + generate_readable_report_metrics(report)
    end
  end
end
