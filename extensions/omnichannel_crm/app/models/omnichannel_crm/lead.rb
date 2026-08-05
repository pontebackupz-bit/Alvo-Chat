module OmnichannelCrm
  class Lead < ApplicationRecord
    self.table_name = 'crm_leads'

    belongs_to :account, class_name: '::Account'
    belongs_to :contact, class_name: '::Contact'
    belongs_to :conversation, class_name: '::Conversation', optional: true
    belongs_to :owner, class_name: '::User', optional: true

    enum :stage, { new_lead: 0, qualified: 1, proposal: 2, won: 3, lost: 4 }, prefix: true

    validates :contact_id, uniqueness: { scope: :account_id }
    validates :stage, presence: true
    validate :chatwoot_records_belong_to_account

    private

    def chatwoot_records_belong_to_account
      errors.add(:contact, 'must belong to the same account') if contact && contact.account_id != account_id
      errors.add(:conversation, 'must belong to the same account') if conversation && conversation.account_id != account_id
      errors.add(:owner, 'must belong to the same account') if account && owner && !account.users.exists?(id: owner_id)
    end
  end
end
