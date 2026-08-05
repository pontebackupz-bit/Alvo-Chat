require 'net/http'
require 'base64'

class OmnichannelCrm::BaileysBridgeClient
  MAX_MEDIA_BYTES = 12.megabytes

  def initialize
    @base_url = ENV.fetch('BAILEYS_BRIDGE_URL', 'http://baileys:3001')
    @token = ENV.fetch('BAILEYS_API_TOKEN', 'local-development-token-change-before-production')
  end

  def session(session_id)
    request(:get, "/sessions/#{session_id}")
  end

  def create_session(session_id)
    request(:post, '/sessions', { session_id: session_id })
  end

  def configure_webhook(session_id, webhook_url, webhook_secret)
    request(:put, "/sessions/#{session_id}/webhook", { webhook_url: webhook_url, webhook_secret: webhook_secret })
  end

  def send_message(session_id, recipient, content, attachment = nil)
    payload = { to: recipient, text: content }
    payload[:media] = media_payload(attachment) if attachment
    request(:post, "/sessions/#{session_id}/messages", payload)
  end

  private

  def media_payload(attachment)
    {
      data: encoded_attachment_file(attachment),
      file_type: attachment.file_type,
      mime_type: attachment.file.content_type,
      file_name: attachment.file.filename.to_s,
      is_sticker: attachment.file.content_type == 'image/webp',
      is_voice_message: attachment.meta&.fetch('is_voice_message', false)
    }
  end

  def encoded_attachment_file(attachment)
    raise "Baileys supports attachments up to #{MAX_MEDIA_BYTES / 1.megabyte} MB" if attachment.file.blob.byte_size > MAX_MEDIA_BYTES

    attachment.file.blob.open { |file| Base64.strict_encode64(file.read) }
  end

  def request(method, path, body = nil)
    uri = URI.join(@base_url, path)
    request = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
    request['Authorization'] = "Bearer #{@token}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json if body

    response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
    return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

    raise "Baileys bridge request failed with status #{response.code}"
  end
end
