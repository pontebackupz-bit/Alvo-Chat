require 'base64'
require 'cgi'
require 'net/http'

class OmnichannelCrm::WppconnectBridgeClient
  MAX_MEDIA_BYTES = 12.megabytes

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

  def contact_name_for(session_id, phone_number)
    contact = request(session_id, :get, "/api/#{session_id}/contact/#{CGI.escape(phone_number)}").fetch('response', {})
    contact = {} unless contact.is_a?(Hash)
    names = [contact['pushname'], contact['formattedName']].filter_map { |name| name.to_s.strip.presence }

    names.find { |name| name.gsub(/\D/, '') != phone_number }
  end

  def delete_session(session_id)
    request(session_id, :post, "/api/#{session_id}/logout-session")
  rescue StandardError
    clear_session_data(session_id)
  else
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
