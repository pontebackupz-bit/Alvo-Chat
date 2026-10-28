require 'base64'
require 'cgi'
require 'net/http'

class OmnichannelCrm::WppconnectBridgeClient
  MAX_MEDIA_BYTES = 20.megabytes
  CONNECTED_SESSION_STATUSES = %w[connected islogged].freeze

  class SessionUnavailable < StandardError; end

  def initialize
    @base_url = ENV.fetch('WPPCONNECT_URL', 'http://wppconnect:21465')
    @secret_key = ENV.fetch('WPPCONNECT_SECRET_KEY')
  end

  def session(session_id)
    request(session_id, :get, "/api/#{session_id}/status-session")
  end

  def create_session(session_id)
    request(session_id, :post, "/api/#{session_id}/start-session", { waitQrCode: false })
  end

  def phone_number_for(session_id, phone_or_lid)
    contact = request(
      session_id,
      :get,
      "/api/#{session_id}/contact/pn-lid/#{CGI.escape(phone_or_lid)}"
    )
    contact.dig('phoneNumber', '_serialized').to_s.split('@').first.gsub(/\D/, '').presence
  end

  def connected_phone_number(session_id)
    request(session_id, :get, "/api/#{session_id}/get-phone-number").fetch('response', '').to_s.gsub(/\D/, '').presence
  end

  def delete_session(session_id)
    # Closing the running browser first prevents an abandoned QR wizard from
    # continuing to rotate codes after the user starts another connection.
    request(session_id, :post, "/api/#{session_id}/close-session")
  rescue StandardError
    # The session can already be closed or partially initialized. Logout below
    # still removes its persisted authentication data in that case.
  ensure
    begin
      request(session_id, :post, "/api/#{session_id}/logout-session")
    rescue StandardError
      # The administrative cleanup below is the final, idempotent fallback.
    end
    clear_session_data(session_id)
  end

  def send_message(session_id, recipient, content, attachment = nil)
    ensure_connected!(session_id)

    response = if attachment
      request(
        session_id,
        :post,
        "/api/#{session_id}/send-file-base64",
        phone: [recipient], base64: data_url_for(attachment), filename: attachment.file.filename.to_s,
        caption: content, isGroup: false, isLid: false
      )
    else
      request(session_id, :post, "/api/#{session_id}/send-message", phone: [recipient], message: content, isGroup: false, isLid: false)
    end

    response.fetch('response').first
  end

  private

  def ensure_connected!(session_id)
    response = session(session_id)
    status = (response['status'] || response.dig('response', 'status')).to_s.downcase
    return if CONNECTED_SESSION_STATUSES.include?(status)

    raise SessionUnavailable, "WPPConnect session #{session_id} is #{status.presence || 'unavailable'}"
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
    raise SessionUnavailable, "WPPConnect session #{session_id} is unavailable: #{e.class}"
  end

  def encoded_attachment_file(attachment)
    raise "WPPConnect supports attachments up to #{MAX_MEDIA_BYTES / 1.megabyte} MB" if attachment.file.blob.byte_size > MAX_MEDIA_BYTES

    attachment.file.blob.open { |file| Base64.strict_encode64(file.read) }
  end

  # WPPConnect's `sendFile` accepts a file path or a *data URL*. A bare Base64
  # string is interpreted as a path by the server, causing documents to fail
  # before they reach WhatsApp. Preserve the attachment MIME type explicitly.
  def data_url_for(attachment)
    mime_type = attachment.file.content_type.to_s.presence || 'application/octet-stream'
    "data:#{mime_type};base64,#{encoded_attachment_file(attachment)}"
  end

  def request(session_id, method, path, body = nil)
    uri = URI.join(@base_url, path)
    request = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
    request['Authorization'] = "Bearer #{session_token(session_id)}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json if body

    response = http_request(uri, request)
    return {} if response.is_a?(Net::HTTPSuccess) && response.body.blank?
    return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

    raise "WPPConnect request failed with status #{response.code}: #{wppconnect_error(response.body)}"
  end

  def wppconnect_error(body)
    payload = JSON.parse(body)
    return payload.to_s.truncate(300).presence || 'no error message returned' unless payload.is_a?(Hash)

    payload['message'].presence || payload['error'].presence || payload.dig('response', 'message').presence || 'no error message returned'
  rescue JSON::ParserError, TypeError
    body.to_s.truncate(300).presence || 'no error message returned'
  end

  def session_token(session_id)
    uri = URI.join(@base_url, "/api/#{session_id}/#{@secret_key}/generate-token")
    response = http_request(uri, Net::HTTP::Post.new(uri))
    raise "WPPConnect token request failed with status #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch('token')
  end

  def clear_session_data(session_id)
    uri = URI.join(@base_url, "/api/#{session_id}/#{@secret_key}/clear-session-data")
    response = http_request(uri, Net::HTTP::Post.new(uri))
    raise "WPPConnect session cleanup failed with status #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  end

  def http_request(uri, request)
    Net::HTTP.start(uri.hostname, uri.port, open_timeout: 5, read_timeout: 30) { |http| http.request(request) }
  end
end
