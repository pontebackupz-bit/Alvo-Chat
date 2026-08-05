# frozen_string_literal: true

require 'omnichannel_crm/engine'

module OmnichannelCrm
  EVENT_NAMES = %w[
    lead.created conversation.created message.received message.sent conversation.resolved
    contact.created lead.converted assignee.changed conversation.status_changed
  ].freeze
end
