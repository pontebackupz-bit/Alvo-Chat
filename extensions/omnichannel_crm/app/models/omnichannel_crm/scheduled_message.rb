class OmnichannelCrm::ScheduledMessage < OmnichannelCrm::ApplicationRecord
  self.table_name = 'crm_scheduled_messages'

  MAX_LENGTH = 4096

  belongs_to :account, class_name: '::Account'
  belongs_to :conversation, class_name: '::Conversation'
  belongs_to :user, class_name: '::User'
  belongs_to :message, class_name: '::Message', optional: true

  enum :status, %w[pending sent failed cancelled].index_by(&:itself)

  validates :content, presence: true, length: { maximum: MAX_LENGTH }
  validates :scheduled_at, presence: true
  validate :scheduled_in_the_future, on: :create

  scope :due, -> { pending.where(scheduled_at: ..Time.current) }

  # Sends it as the person who scheduled it, through the normal reply path
  # (WhatsApp delivery included).
  def deliver!
    with_lock do
      return unless pending?

      message = conversation.messages.create!(
        account_id: account_id, inbox_id: conversation.inbox_id, message_type: :outgoing, sender: user,
        content: content, content_attributes: { 'scheduled_message_id' => id }
      )
      update!(status: :sent, message: message, sent_at: Time.current, error_message: nil)
    end
  rescue StandardError => e
    update_columns(status: 'failed', error_message: e.message.truncate(250), updated_at: Time.current)
  end

  private

  def scheduled_in_the_future
    errors.add(:scheduled_at, 'precisa ser no futuro') if scheduled_at.present? && scheduled_at < 1.minute.ago
  end
end
