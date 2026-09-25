module OmnichannelCrm
  module WorkflowImporters
    class EzChatFlowImporter
      NODE_TYPES = {
        'start' => 'start', 'chat' => 'send_message', 'conditional' => 'condition', 'split' => 'switch', 'code' => 'code',
        'flowVariable' => 'workflow_variable', 'userVariable' => 'contact_variable',
        'googleSheets' => 'google_sheets', 'oracleDB' => 'oracle_database',
        'handoverAttendance' => 'transfer_team', 'onlineAgentAttendance' => 'assign_agent',
        'labelAttendance' => 'add_label', 'jump' => 'execute_subflow', 'startInactivity' => 'inactivity_control',
        'annotation' => 'annotation', 'notes' => 'note', 'json' => 'json_response'
      }.freeze
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
      end

      def import
        original_nodes = @payload.dig('flow', 'nodes')
        nodes = original_nodes.filter_map { |node| convert_node(node) }
        valid_ids = nodes.pluck('id').to_set
        connections = @payload.dig('flow', 'edges').filter_map { |edge| convert_edge(edge, valid_ids) }
        variables = extract_variables(nodes)

        {
          name: @payload['name'].presence || File.basename(@filename.to_s, File.extname(@filename.to_s)),
          description: @payload['description'].to_s,
          source: 'ezchat',
          source_workflow_id: @payload['id'] || @payload['_id'],
          nodes: nodes,
          connections: connections,
          variables: variables,
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
        type = NODE_TYPES.fetch(original_type, 'unsupported_imported_node')
        unsupported = type == 'unsupported_imported_node'
        data['originalType'] = original_type if unsupported
        data['originalData'] = sanitize(node['data']) if unsupported
        data['requiresCredential'] = true if CREDENTIAL_NODES.include?(original_type)
        data['conditions'] = normalize_conditions(data['conditions']) if original_type == 'conditional'
        data['pendingSubflow'] = subflow_reference(data) if original_type == 'jump'
        data['variables'] = parse_variable_data(data['data']) if %w[flowVariable userVariable].include?(original_type)
        data = annotation_data(data) if %w[annotation notes].include?(original_type)
        @warnings << { 'kind' => 'unsupported_node', 'nodeId' => node['id'], 'originalType' => original_type } if unsupported

        { 'id' => node['id'].to_s, 'type' => type, 'originalType' => original_type,
          'position' => position_for(node), 'data' => data }
      end

      def convert_edge(edge, valid_ids)
        unless edge.is_a?(Hash) && valid_ids.include?(edge['source'].to_s) && valid_ids.include?(edge['target'].to_s)
          @warnings << { 'kind' => 'invalid_connection', 'edgeId' => edge.is_a?(Hash) ? edge['id'] : nil }
          return
        end
        { 'id' => edge['id'].presence || SecureRandom.uuid, 'source' => edge['source'].to_s,
          'target' => edge['target'].to_s, 'sourceHandle' => edge['sourceHandle'],
          'targetHandle' => edge['targetHandle'], 'label' => edge['label'], 'data' => sanitize(edge['data'] || {}) }
      end

      def position_for(node)
        position = node['position'].is_a?(Hash) ? node['position'] : {}
        { 'x' => Float(position['x'] || 0), 'y' => Float(position['y'] || 0) }
      rescue ArgumentError, TypeError
        { 'x' => 0, 'y' => 0 }
      end

      def extract_variables(nodes)
        nodes.filter_map do |node|
          category = case node['type']; when 'workflow_variable' then 'workflow'; when 'contact_variable' then 'contact'; end
          next unless category
          data = node['data']
          variables = data['variables'].presence || { data['name'] || data['variable'] || data['key'] => data['value'] || data['defaultValue'] }
          variables.filter_map do |name, value|
            next if name.blank?
            { 'name' => name.to_s, 'scope' => category, 'defaultValue' => value }
          end
        end.flatten.uniq { |variable| [variable['scope'], variable['name']] }
      end

      def subflow_reference(data)
        flow = data['flow']
        flow.is_a?(Hash) ? flow['name'] : (data['flowName'] || flow || data['targetFlow'] || data['name'])
      end

      def normalize_conditions(conditions)
        operators = { 'eq' => '=', 'neq' => '!=', 'gt' => '>', 'gte' => '>=', 'lt' => '<', 'lte' => '<=',
                      'contains' => 'contains', 'notContains' => 'not contains', 'exists' => 'exists', 'empty' => 'empty' }
        Array(conditions).filter_map do |condition|
          next unless condition.is_a?(Hash)
          { 'id' => condition['id'], 'left' => condition['left'], 'operator' => operators.fetch(condition['comparator'], condition['comparator']),
            'right' => condition['right'], 'originalComparator' => condition['comparator'] }
        end
      end

      def parse_variable_data(value)
        return {} unless value.is_a?(String)

        parsed = JSON.parse(value, max_nesting: 25)
        parsed.is_a?(Hash) ? sanitize(parsed) : {}
      rescue JSON::ParserError
        {}
      end

      def annotation_data(data)
        return { 'markdown' => data['markdown'].to_s, 'color' => data['color'] } if data['markdown'].present?

        { 'comments' => Array(data['comments']).filter_map { |comment| comment.is_a?(Hash) ? comment['comment'].to_s.presence : nil } }
      end

      def report(original_nodes, original_edges, nodes, connections)
        unsupported = nodes.count { |node| node['type'] == 'unsupported_imported_node' }
        credentials = nodes.count { |node| node.dig('data', 'requiresCredential') }
        subflows = nodes.filter_map { |node| node.dig('data', 'pendingSubflow') }.uniq.size
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
