# Where the replies of each WhatsApp number were written: in AlvoChat (by an
# agent) or on the connected phone. WhatsApp does not say who typed on the
# phone, so these are counted per number, not per agent. Automatic messages
# (flows, bot) and history brought in by "Importar histórico" are left out.
module OmnichannelCrm::ReplySources
  PHONE_SQL = "#{OmnichannelCrm::MessageAttributesSql.field('external_echo')} = 'true'".freeze
  IMPORTED_SQL = "COALESCE(#{OmnichannelCrm::MessageAttributesSql.field('imported_from_whatsapp')}, 'false') <> 'true'".freeze

  # Prepended on V2::Reports::InboxSummaryBuilder: Relatórios > Caixas de
  # Entrada gets the two counts for the selected period.
  module InboxSummary
    def build
      counts = OmnichannelCrm::ReplySources.by_inbox(::Message.where(account_id: account.id, created_at: range))
      super.map do |row|
        row.merge(system_replies_count: counts.dig(row[:id], :system) || 0, phone_replies_count: counts.dig(row[:id], :phone) || 0)
      end
    end
  end

  module_function

  # { inbox_id => { system:, phone: } } for the given messages.
  def by_inbox(messages)
    replies = messages.outgoing.where(private: false).where(IMPORTED_SQL).reorder(nil)
    system = replies.where(sender_type: 'User').group(:inbox_id).count
    phone = replies.where(PHONE_SQL).group(:inbox_id).count
    (system.keys | phone.keys).index_with { |id| { system: system.fetch(id, 0), phone: phone.fetch(id, 0) } }
  end
end
