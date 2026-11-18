# Contact CSV import without duplicate customers: phone numbers are matched
# regardless of formatting (and of the Brazilian ninth digit), and rows of the
# same file that share a phone number become a single contact.
module OmnichannelCrm::ContactImportDedup
  module Manager
    def build_contact(params)
      key = OmnichannelCrm::PhoneNumber.normalize(params[:phone_number])
      duplicate = key && contacts_by_phone[key]
      return merge_duplicate_row(duplicate, params) if duplicate

      contact = super
      OmnichannelCrm::PhoneNumber.variants(key).each { |variant| contacts_by_phone[variant] = contact } if key
      contact
    end

    def find_contact_by_phone_number(params)
      phone = OmnichannelCrm::PhoneNumber.normalize(params[:phone_number])
      return unless phone

      matches = @account.contacts.where(phone_number: OmnichannelCrm::PhoneNumber.variants(phone)).order(:id).to_a
      matches.find { |contact| contact.phone_number == phone } || matches.first
    end

    def format_phone_number(phone_number)
      OmnichannelCrm::PhoneNumber.normalize(phone_number) || phone_number
    end

    # Keep the number already stored (it is the one WhatsApp delivers to) when
    # the file spells the same phone differently.
    def update_contact_with_merged_attributes(params, contact)
      super(same_phone?(contact, params) ? params.except(:phone_number) : params, contact)
    end

    private

    def contacts_by_phone
      @contacts_by_phone ||= {}
    end

    def same_phone?(contact, params)
      phone = OmnichannelCrm::PhoneNumber.normalize(params[:phone_number])
      phone.present? && contact.phone_number.present? && OmnichannelCrm::PhoneNumber.variants(phone).include?(contact.phone_number)
    end

    def merge_duplicate_row(contact, params)
      contact.email = params[:email] if contact.email.blank? && params[:email].present?
      contact.identifier = params[:identifier] if contact.identifier.blank? && params[:identifier].present?
      update_contact_attributes(params.except(:phone_number), contact)
      contact.save if contact.persisted?
      contact
    end
  end

  module Job
    private

    # A contact repeated in the file is inserted once, with the labels of all its rows.
    def import_contacts(contacts_with_labels)
      merged = contacts_with_labels.group_by { |item| item[:contact].object_id }.map do |_id, items|
        { contact: items.first[:contact], labels: items.flat_map { |item| item[:labels] }.uniq }
      end
      super(merged)
    end
  end
end
