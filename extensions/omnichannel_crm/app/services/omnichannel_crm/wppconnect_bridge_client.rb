require 'base64'
require 'cgi'
require 'net/http'

class OmnichannelCrm::WppconnectBridgeClient
  MAX_MEDIA_BYTES = 12.megabytes
  MEDIA_DOWNLOAD_ATTEMPTS = 3

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

  # WPPConnect emits the onmessage webhook before its asynchronous media
  # auto-download finishes. Download the exact message by its serialized ID;
  # passing the mutable webhook object makes recent WPPConnect versions return
  # 400 and using `body` can persist an older attachment.
  def download_media(session_id, message_id)
    failure = nil

    MEDIA_DOWNLOAD_ATTEMPTS.times do |attempt|
      response = request(session_id, :post, "/api/#{session_id}/download-media", messageId: message_id.to_s)
      base64 = response.fetch('base64', '').to_s.sub(%r{\Adata:[^;]+;base64,}, '')
      return { data: base64, mime_type: response['mimetype'].to_s } if base64.present?

      failure = 'WPPConnect returned an empty media payload'
      sleep((attempt + 1) * 0.25)
    rescue StandardError => e
      failure = e
      sleep((attempt + 1) * 0.25) if attempt < MEDIA_DOWNLOAD_ATTEMPTS - 1
    end

    raise failure || 'WPPConnect media download failed'
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
    response = if attachment
      request(
        session_id,
        :post,
        "/api/#{session_id}/send-file-base64",
        phone: [recipient], base64: encoded_attachment_file(attachment), filename: attachment.file.filename.to_s,
        caption: content, isGroup: false, isLid: false
      )
    else
      request(session_id, :post, "/api/#{session_id}/send-message", phone: [recipient], message: content, isGroup: false, isLid: false)
    end

    response.fetch('response').first
  end

  private

  def encoded_attachment_file(attachment)
    raise "WPPConnect supports attachments up to #{MAX_MEDIA_BYTES / 1.megabyte} MB" if attachment.file.blob.byte_size > MAX_MEDIA_BYTES

    attachment.file.blob.open { |file| Base64.strict_encode64(file.read) }
  end

  def request(session_id, method, path, body = nil)
    uri = URI.join(@base_url, path)
    request = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
    request['Authorization'] = "Bearer #{session_token(session_id)}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json if body

    response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
    return {} if response.is_a?(Net::HTTPSuccess) && response.body.blank?
    return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

    raise "WPPConnect request failed with status #{response.code}"
  end

  def session_token(session_id)
    uri = URI.join(@base_url, "/api/#{session_id}/#{@secret_key}/generate-token")
    response = Net::HTTP.post(uri, '')
    raise "WPPConnect token request failed with status #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch('token')
  end

  def clear_session_data(session_id)
    uri = URI.join(@base_url, "/api/#{session_id}/#{@secret_key}/clear-session-data")
    response = Net::HTTP.post(uri, '')
    raise "WPPConnect session cleanup failed with status #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  end
end
