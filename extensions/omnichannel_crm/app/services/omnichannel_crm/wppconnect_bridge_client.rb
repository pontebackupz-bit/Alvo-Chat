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

  # Address of the WhatsApp profile picture of a person or group, if public.
  def profile_pic_url(session_id, jid)
    query = OmnichannelCrm::WhatsappGroup.jid?(jid) ? '?isGroup=true' : ''
    response = request(session_id, :get, "/api/#{session_id}/profile-pic/#{CGI.escape(jid)}#{query}")
    picture = response.is_a?(Hash) ? response['response'] : nil
    picture.is_a?(Hash) ? (picture['eurl'].presence || picture['imgFull'].presence) : nil
  end

  # The `@lid` chat id WhatsApp uses for a phone number, when it has one.
  def lid_for(session_id, phone)
    contact = request(session_id, :get, "/api/#{session_id}/contact/pn-lid/#{CGI.escape(phone)}")
    contact.dig('lid', '_serialized').presence
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

  # Most recent chats on the phone (people and groups).
  def list_chats(session_id, count)
    response = request(session_id, :post, "/api/#{session_id}/list-chats", { count: count })
    Array(response.is_a?(Hash) ? response['response'] : response)
  end

  # Latest messages of one chat, oldest first.
  def chat_messages(session_id, jid, count)
    response = request(session_id, :get, "/api/#{session_id}/get-messages/#{CGI.escape(jid)}?count=#{count.to_i}")
    Array(response.is_a?(Hash) ? response['response'] : response)
  end

  # The group's name, for conversations created from group messages.
  def chat_name(session_id, jid)
    chat = request(session_id, :get, "/api/#{session_id}/chat-by-id/#{CGI.escape(jid)}?isGroup=#{jid.end_with?('@g.us')}")
    chat = chat['response'] if chat['response'].is_a?(Hash)
    [chat['name'], chat.dig('contact', 'name'), chat['formattedTitle'], chat.dig('groupMetadata', 'subject')]
      .filter_map { |name| name.to_s.strip.presence }.first
  end

  # `group:` sends to a group id (`120363...`), otherwise to a phone number.
  def send_message(session_id, recipient, content, attachment = nil, group: false)
    ensure_connected!(session_id)

    response = if attachment
      request(
        session_id,
        :post,
        "/api/#{session_id}/send-file-base64",
        phone: [recipient], base64: data_url_for(attachment), filename: attachment.file.filename.to_s,
        caption: content, isGroup: group, isLid: false
      )
    else
      request(session_id, :post, "/api/#{session_id}/send-message", phone: [recipient], message: content, isGroup: group, isLid: false)
    end

    response.fetch('response').first
  end

  # Location, contact card, poll and option list. Each returns { 'id' => ... }.
  def send_location(session_id, recipient, lat:, lng:, title: nil, address: nil, group: false)
    rich_request(session_id, 'send-location', recipient, group, lat: lat.to_s, lng: lng.to_s, title: title, address: address)
  end

  def send_contact(session_id, recipient, phone:, name: nil, group: false)
    rich_request(session_id, 'contact-vcard', recipient, group, contactsId: [phone], name: name)
  end

  def send_poll(session_id, recipient, name:, choices:, selectable_count: 1, group: false)
    rich_request(session_id, 'send-poll-message', recipient, group, name: name, choices: choices,
                                                                      options: { selectableCount: selectable_count })
  end

  def send_list(session_id, recipient, description:, button_text:, sections:, group: false)
    rich_request(session_id, 'send-list-message', recipient, group, description: description, buttonText: button_text,
                                                                      sections: sections)
  end

  # WPPConnect only auto-downloads media for received messages, so media sent
  # from the connected phone must be fetched explicitly. Returns base64 and mimetype.
  def download_media(session_id, message_id)
    request(session_id, :post, "/api/#{session_id}/download-media", messageId: message_id).slice('base64', 'mimetype')
  end

  private

  def rich_request(session_id, route, recipient, group, body)
    ensure_connected!(session_id)
    response = request(session_id, :post, "/api/#{session_id}/#{route}", { phone: [recipient], isGroup: group, isLid: false }.merge(body))
    result = response.is_a?(Hash) ? response['response'] : response
    result = result.first if result.is_a?(Array)
    id = result.is_a?(Hash) ? (result['id'].is_a?(Hash) ? result['id']['_serialized'] : result['id']) : result
    { 'id' => id.presence || "alvochat-#{SecureRandom.hex(8)}" }
  end

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
