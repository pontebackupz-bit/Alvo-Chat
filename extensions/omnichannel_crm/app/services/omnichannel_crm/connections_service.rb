# WhatsApp numbers connected to the account: who registered each one, its
# live status on the bridge and how much it is being used. Administrators see
# every number; other users the inboxes they can access.
class OmnichannelCrm::ConnectionsService
  BRIDGE_PROVIDERS = %w[wppconnect baileys].freeze
  CONNECTED = %w[connected islogged open inchat].freeze
  CONNECTING = %w[qrcode qrreadsuccess notlogged starting connecting initializing].freeze

  def initialize(account:, user:)
    @account = account
    @user = user
  end

  def perform
    inboxes = whatsapp_inboxes.to_a
    creators = creators_for(inboxes)
    open_counts = @account.conversations.open.where(inbox_id: inboxes.map(&:id)).group(:inbox_id).count
    statuses = inboxes.map { |inbox| Thread.new { live_status(inbox) } }.map(&:value)
    inboxes.zip(statuses).map { |inbox, status| row(inbox, status, creators[inbox.id], open_counts.fetch(inbox.id, 0)) }
  end

  def find(inbox_id)
    whatsapp_inboxes.find(inbox_id)
  end

  def self.provider(inbox)
    return 'whatsapp_cloud' if inbox.channel_type == 'Channel::Whatsapp'

    inbox.channel.additional_attributes.to_h['provider']
  end

  def self.reconnect(inbox)
    session_id = inbox.channel.additional_attributes.to_h['session_id']
    case provider(inbox)
    when 'wppconnect' then OmnichannelCrm::WppconnectBridgeClient.new.create_session(session_id)
    when 'baileys' then OmnichannelCrm::BaileysBridgeClient.new.create_session(session_id)
    end
  end

  private

  def whatsapp_inboxes
    scope = administrator? ? @account.inboxes : @user.assigned_inboxes.where(account_id: @account.id)
    api_ids = Channel::Api.where(account_id: @account.id)
                          .where("additional_attributes ->> 'provider' IN (?)", BRIDGE_PROVIDERS).select(:id)
    scope.includes(:channel)
         .where(channel_type: 'Channel::Api', channel_id: api_ids)
         .or(scope.includes(:channel).where(channel_type: 'Channel::Whatsapp'))
         .order(:name)
  end

  def administrator?
    @account.account_users.find_by(user_id: @user.id)&.administrator?
  end

  def row(inbox, status, creator, open_conversations)
    attributes = inbox.channel.respond_to?(:additional_attributes) ? inbox.channel.additional_attributes.to_h : {}
    team = @account.teams.find_by(id: attributes['default_team_id'])
    {
      id: inbox.id, name: inbox.name, provider: self.class.provider(inbox), status: status,
      phone: phone_for(inbox, attributes), team: team && { id: team.id, name: team.name },
      created_by: creator && { id: creator.id, name: creator.name, email: creator.email },
      created_at: inbox.created_at, open_conversations: open_conversations,
      last_activity_at: @account.conversations.where(inbox_id: inbox.id).maximum(:last_activity_at)
    }
  end

  def phone_for(inbox, attributes)
    return inbox.channel.phone_number if inbox.channel.respond_to?(:phone_number)

    attributes['phone_number']
  end

  # The person saved on the number when it was connected or, for older
  # numbers, the author of the inbox creation in the audit trail.
  def creators_for(inboxes)
    ids = inboxes.to_h { |inbox| [inbox.id, inbox.channel.try(:additional_attributes).to_h['created_by_id']] }
    audited_creators(inboxes.map(&:id) - ids.compact_blank.keys).each { |inbox_id, user_id| ids[inbox_id] ||= user_id }
    users = User.where(id: ids.values.compact).index_by(&:id)
    ids.transform_values { |user_id| users[user_id.to_i] }
  end

  def audited_creators(inbox_ids)
    return {} unless defined?(Audited::Audit) && inbox_ids.any?

    Audited::Audit.where(auditable_type: 'Inbox', auditable_id: inbox_ids, action: 'create', user_type: 'User')
                  .pluck(:auditable_id, :user_id).to_h
  end

  def live_status(inbox)
    session_id = inbox.channel.try(:additional_attributes).to_h['session_id']
    case self.class.provider(inbox)
    when 'wppconnect' then normalize(OmnichannelCrm::WppconnectBridgeClient.new.session(session_id)['status'])
    when 'baileys' then normalize(OmnichannelCrm::BaileysBridgeClient.new.session(session_id).to_h['status'])
    else 'connected'
    end
  rescue StandardError => e
    Rails.logger.warn("Connection status for inbox #{inbox.id} failed: #{e.message}")
    'unreachable'
  ensure
    ActiveRecord::Base.connection_pool.release_connection
  end

  def normalize(status)
    value = status.to_s.downcase
    return 'connected' if CONNECTED.include?(value)
    return 'connecting' if CONNECTING.include?(value)

    'disconnected'
  end
end
