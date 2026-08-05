require 'faraday'
require 'uri'

module OmnichannelCrm
  module N8n
    class Client
      def initialize(connection)
        @connection = connection
      end

      def workflows
        response = connection.get('api/v1/workflows')
        parse(response)
      end

      def execute_webhook(webhook_path, payload)
        response = connection.post(webhook_request_path(webhook_path), payload.to_json, webhook_headers)
        parse(response)
      end

      private

      def connection
        @connection_client ||= Faraday.new(url: @connection.base_url) do |client|
          client.headers['X-N8N-API-KEY'] = @connection.api_key
          client.headers['Content-Type'] = 'application/json'
          client.options.timeout = 15
          client.options.open_timeout = 5
        end
      end

      def parse(response)
        body = response.body.present? ? JSON.parse(response.body) : {}
        return body if response.success?

        raise "n8n request failed (#{response.status}): #{body}"
      end

      def webhook_request_path(webhook_path)
        path = webhook_path.to_s.strip
        path = URI.parse(path).path if path.match?(%r{\Ahttps?://}i)
        path = path.delete_prefix('/')

        return path if path.start_with?('webhook/', 'webhook-test/')

        "webhook/#{path}"
      rescue URI::InvalidURIError
        "webhook/#{webhook_path.to_s.delete_prefix('/')}"
      end

      def webhook_headers
        return {} if @connection.webhook_auth_header.blank? || @connection.webhook_auth_value.blank?

        { @connection.webhook_auth_header => @connection.webhook_auth_value }
      end
    end
  end
end
