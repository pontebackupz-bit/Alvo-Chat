class Contacts::ExportCsvBuilder
  LABELS_COLUMN = 'labels'.freeze
  LABELS_DELIMITER = ','.freeze
  DEFAULT_COLUMNS = %w[id name email phone_number labels].freeze
  # Prepend UTF-8 BOM so that spreadsheet applications (e.g. Excel)
  # correctly recognise the file encoding for non-ASCII characters.
  BOM = "\xEF\xBB\xBF".freeze

  pattr_initialize [:account!, :account_user!, :column_names, :params]

  def perform
    headers = valid_headers
    contacts_to_export = contacts.to_a
    preload_contact_labels(contacts_to_export) if headers.include?(LABELS_COLUMN)

    csv_data = CSV.generate do |csv|
      csv << headers
      contacts_to_export.each do |contact|
        csv << headers.map { |header| value_for_header(contact, header) }
      end
    end

    "#{BOM}#{csv_data}"
  end

  def filename
    "#{account.name}_#{account.id}_contacts.csv"
  end

  private

  def value_for_header(contact, header)
    return contact_labels_by_id.fetch(contact.id, []).join(LABELS_DELIMITER) if header == LABELS_COLUMN

    contact.send(header)
  end

  def approved_labels
    @approved_labels ||= account.labels.pluck(:title)
  end

  def preload_contact_labels(contacts_to_export)
    contact_ids = contacts_to_export.map(&:id)
    return if contact_ids.blank?

    ActsAsTaggableOn::Tagging
      .joins(:tag)
      .where(context: LABELS_COLUMN, taggable_type: 'Contact', taggable_id: contact_ids)
      .where(tags: { name: approved_labels })
      .pluck(:taggable_id, 'tags.name')
      .each { |contact_id, label| contact_labels_by_id[contact_id] << label }
  end

  def contact_labels_by_id
    @contact_labels_by_id ||= Hash.new { |hash, contact_id| hash[contact_id] = [] }
  end

  def contacts
    return ::Contacts::FilterService.new(account, account_user, params).perform[:contacts] if params&.dig(:payload).present?
    return resolved_contacts.tagged_with(params[:label], any: true) if params&.dig(:label).present?

    resolved_contacts
  end

  def resolved_contacts
    account.contacts.resolved_contacts(use_crm_v2: account.feature_enabled?('crm_v2'))
  end

  def valid_headers
    requested_headers = column_names.presence || DEFAULT_COLUMNS

    # Keep requested header order while allowing the virtual labels column.
    requested_headers.select do |header|
      header == LABELS_COLUMN || Contact.column_names.include?(header)
    end.uniq
  end
end
