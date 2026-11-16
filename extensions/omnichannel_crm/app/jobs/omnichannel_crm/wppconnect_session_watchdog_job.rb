# Keeps connected WPPConnect numbers online. The bridge stores each session's
# token, so restarting a dropped session reconnects without a new QR code.
class OmnichannelCrm::WppconnectSessionWatchdogJob < ApplicationJob
  queue_as :low
  # Sessions waiting for a QR scan or still starting must be left alone.
  RESTART_STATUSES = %w[closed disconnected notlogged browserclose unpaired timeout].freeze

  def perform
    bridge = OmnichannelCrm::WppconnectBridgeClient.new
    session_ids.each { |session_id| keep_alive(bridge, session_id) }
  end

  private

  def session_ids
    Channel::Api.where("additional_attributes ->> 'provider' = 'wppconnect'")
                .filter_map { |channel| channel.additional_attributes['session_id'].presence }
  end

  def keep_alive(bridge, session_id)
    status = bridge.session(session_id)['status'].to_s.downcase
    bridge.create_session(session_id) if RESTART_STATUSES.include?(status)
  rescue StandardError => e
    Rails.logger.warn("WPPConnect watchdog could not check #{session_id}: #{e.message}")
    restart_quietly(bridge, session_id)
  end

  def restart_quietly(bridge, session_id)
    bridge.create_session(session_id)
  rescue StandardError => e
    Rails.logger.warn("WPPConnect watchdog could not restart #{session_id}: #{e.message}")
  end
end
