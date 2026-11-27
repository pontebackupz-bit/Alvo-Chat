class Account::ContactsExportJob < ApplicationJob
  queue_as :low

  def perform(account_id, user_id, column_names, params)
    @account = Account.find(account_id)
    @account_user = @account.users.find(user_id)

    builder = Contacts::ExportCsvBuilder.new(account: @account, account_user: @account_user, column_names: column_names, params: params)
    @account.contacts_export.attach(io: StringIO.new(builder.perform), filename: builder.filename, content_type: 'text/csv')
    send_mail
  end

  private

  def send_mail
    file_url = account_contact_export_url
    mailer = AdministratorNotifications::AccountNotificationMailer.with(account: @account)
    mailer.contact_export_complete(file_url, @account_user.email)&.deliver_later
  end

  def account_contact_export_url
    Rails.application.routes.url_helpers.rails_blob_url(@account.contacts_export)
  end
end
