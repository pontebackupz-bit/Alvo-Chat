module OmnichannelCrm
  module WorkflowImporters
    class EzChatFlowImporter
      CREDENTIAL_NODES = %w[googleSheets oracleDB httpRequest].freeze
      SECRET_KEYS = /(?:api[_-]?key|access[_-]?token|refresh[_-]?token|password|secret|credential)/i
      SECRET_VALUE = /(?:api[_-]?key|access[_-]?token|refresh[_-]?token|password|secret|x-amz-security-token|awsaccesskeyid|signature=)/i
      DANGEROUS_KEYS = %w[__proto__ prototype constructor].freeze

      def self.can_import?(payload, filename: nil)
        payload.is_a?(Hash) && payload['flow'].is_a?(Hash) && payload.dig('flow', 'nodes').is_a?(Array) &&
          payload.dig('flow', 'edges').is_a?(Array)
      end

      def initialize(payload, filename:)
        @payload = payload
        @filename = filename
        @warnings = []
        @handles = {}
      end

      def import
        original_nodes = @payload.dig('flow', 'nodes')
        nodes = original_nodes.filter_map { |node| convert_node(node) }
        valid_ids = nodes.pluck('id').to_set
        connections = unique_connections(@payload.dig('flow', 'edges').filter_map { |edge| convert_edge(edge, valid_ids) })

        {
          name: @payload['name'].presence || File.basename(@filename.to_s, File.extname(@filename.to_s)),
          description: @payload['description'].to_s,
          source: 'ezchat',
          source_workflow_id: @payload['id'] || @payload['_id'],
          nodes: nodes,
          connections: connections,
          variables: extract_variables(nodes),
          metadata: {
            'importSource' => 'ezchat', 'originalWorkflowName' => @payload['name'].to_s,
            'importedAt' => Time.current.iso8601, 'filename' => File.basename(@filename.to_s)
          },
          import_report: report(original_nodes, @payload.dig('flow', 'edges'), nodes, connections)
        }
      end

      private

      def convert_node(node)
        unless node.is_a?(Hash) && node['id'].present?
          @warnings << { 'kind' => 'invalid_node', 'message' => 'Um node sem identificador foi ignorado.' }
          return
        end

        original_type = node['type'].to_s
        data = sanitize(node['data'].is_a?(Hash) ? node['data'] : {})
        converted = EzChatNodeConverter.new(original_type, data).convert || unsupported(node, original_type, data)
        @handles[node['id'].to_s] = converted[:handles] if converted[:type] == 'menu' || converted[:handles].any?
        converted[:data]['requiresCredential'] = true if CREDENTIAL_NODES.include?(original_type)
        { 'id' => node['id'].to_s, 'type' => converted[:type], 'originalType' => original_type,
          'position' => position_for(node), 'data' => converted[:data].compact }
      end

      def unsupported(node, original_type, data)
        @warnings << { 'kind' => 'unsupported_node', 'nodeId' => node['id'], 'originalType' => original_type }
        { type: 'unsupported_imported_node', data: { 'title' => data['title'], 'originalType' => original_type, 'originalData' => data },
          handles: {} }
      end

      # Outputs are renamed for the runner. Menu outputs that no button of
      # the block uses any more are dropped.
      def convert_edge(edge, valid_ids)
        unless edge.is_a?(Hash) && valid_ids.include?(edge['source'].to_s) && valid_ids.include?(edge['target'].to_s)
          @warnings << { 'kind' => 'invalid_connection', 'edgeId' => edge.is_a?(Hash) ? edge['id'] : nil }
          return
        end
        handle = source_handle(edge)
        return if handle.nil?

        { 'id' => edge['id'].presence || SecureRandom.uuid, 'source' => edge['source'].to_s, 'target' => edge['target'].to_s,
          'sourceHandle' => handle, 'primary' => handle == "option:#{edge['sourceHandle']}" }
      end

      def source_handle(edge)
        original = edge['sourceHandle'].presence || 'next'
        handles = @handles[edge['source'].to_s]
        return original unless handles
        return handles[original] if handles.key?(original)
        return original unless handles.values.any? { |handle| handle.start_with?('option:') } && original.match?(/\A[\w-]{8,}\z/)

        @warnings << { 'kind' => 'stale_connection', 'edgeId' => edge['id'] }
        nil
      end

      # One connection per output, as the editor expects; the link drawn from
      # the option's own button wins over the other channels' copies.
      def unique_connections(connections)
        connections.each_with_index.sort_by { |connection, index| [connection['primary'] ? 0 : 1, index] }.map(&:first)
                   .uniq { |connection| [connection['source'], connection['sourceHandle']] }
                   .map { |connection| connection.except('primary') }
      end

      def position_for(node)
        position = node['position'].is_a?(Hash) ? node['position'] : {}
        { 'x' => Float(position['x'] || 0), 'y' => Float(position['y'] || 0) }
      rescue ArgumentError, TypeError
        { 'x' => 0, 'y' => 0 }
      end

      def extract_variables(nodes)
        nodes.select { |node| node['type'] == 'set_variables' }.flat_map do |node|
          scope = node.dig('data', 'scope') == 'contact' ? 'contact' : 'workflow'
          (node.dig('data', 'values') || {}).map { |name, value| { 'name' => name.to_s, 'scope' => scope, 'defaultValue' => value } }
        end.uniq { |variable| [variable['scope'], variable['name']] }
      end

      def report(original_nodes, original_edges, nodes, connections)
        unsupported = nodes.count { |node| node['type'] == 'unsupported_imported_node' }
        credentials = nodes.count { |node| node.dig('data', 'requiresCredential') }
        subflows = nodes.filter_map { |node| node.dig('data', 'flow_name') if node['type'] == 'subflow' }.uniq.size
        { 'nodesTotal' => original_nodes.size, 'nodesConverted' => nodes.size - unsupported,
          'nodesUnsupported' => unsupported, 'credentialsRequired' => credentials, 'subflowsPending' => subflows,
          'connectionsTotal' => original_edges.size, 'connectionsConverted' => connections.size,
          'connectionsInvalid' => original_edges.size - connections.size, 'warnings' => @warnings }
      end

      def sanitize(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, item), result|
            key = key.to_s
            next if DANGEROUS_KEYS.include?(key)
            result[key] = SECRET_KEYS.match?(key) ? nil : sanitize(item)
          end
        when Array then value.map { |item| sanitize(item) }
        when String then SECRET_VALUE.match?(value) ? nil : value
        when Numeric, TrueClass, FalseClass, NilClass then value
        else value.to_s
        end
      end
    end
  end
end
