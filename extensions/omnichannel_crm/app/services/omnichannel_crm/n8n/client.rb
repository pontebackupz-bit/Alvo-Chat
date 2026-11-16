require 'faraday'
require 'uri'

module OmnichannelCrm
  module N8n
    class Client
      class RequestError < StandardError; end

      # Workflow settings accepted by the n8n public API; it rejects any other key.
      WORKFLOW_SETTINGS = %w[
        saveExecutionProgress saveManualExecutions saveDataErrorExecution saveDataSuccessExecution
        executionTimeout errorWorkflow timezone executionOrder callerPolicy
      ].freeze

      def initialize(connection)
        @connection = connection
      end

      def workflows
        response = connection.get('api/v1/workflows')
        parse(response)
      end

      def workflow(id)
        parse(connection.get("api/v1/workflows/#{id}"))
      end

      def create_workflow(attributes)
        parse(connection.post('api/v1/workflows', workflow_body(attributes).to_json))
      end

      def update_workflow(id, attributes)
        parse(connection.put("api/v1/workflows/#{id}", workflow_body(attributes).to_json))
      end

      def set_workflow_active(id, active)
        parse(connection.post("api/v1/workflows/#{id}/#{active ? 'activate' : 'deactivate'}"))
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

        raise RequestError, "n8n request failed (#{response.status}): #{body['message'] || body}"
      end

      def workflow_body(attributes)
        {
          name: attributes.fetch(:name),
          nodes: attributes.fetch(:nodes),
          connections: attributes.fetch(:connections),
          settings: attributes.fetch(:settings, {}).slice(*WORKFLOW_SETTINGS)
        }
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
