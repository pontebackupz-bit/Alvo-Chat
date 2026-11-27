require 'rails_helper'

RSpec.describe OmnichannelCrm::WorkflowImporters::EzChatFlowImporter do
  let(:payload) do
    {
      'id' => 'ez-menu-1', 'name' => 'Menu principal', 'description' => 'Fluxo de teste',
      'flow' => {
        'nodes' => [
          { 'id' => 'chat-1', 'type' => 'chat', 'position' => { 'x' => 30, 'y' => 50 }, 'data' => { 'message' => 'Olá' } },
          { 'id' => 'variable-1', 'type' => 'flowVariable', 'data' => { 'name' => 'askedTimesMenu', 'value' => 0 } },
          { 'id' => 'sheet-1', 'type' => 'googleSheets', 'data' => { 'apiKey' => 'secret', 'sheet' => 'Clientes' } },
          { 'id' => 'jump-1', 'type' => 'jump', 'data' => { 'flowName' => 'Rastrear pedido' } },
          { 'id' => 'custom-1', 'type' => 'oracleCustomOperation', 'data' => { 'password' => 'never-store' } }
        ],
        'edges' => [
          { 'id' => 'valid', 'source' => 'chat-1', 'target' => 'variable-1', 'sourceHandle' => 'next' },
          { 'id' => 'broken', 'source' => 'chat-1', 'target' => 'missing' }
        ]
      }
    }
  end

  describe '.can_import?' do
    it 'detects the EZ.Chat flow structure, not only the filename' do
      expect(described_class.can_import?(payload, filename: 'anything.json')).to be(true)
      expect(described_class.can_import?({ 'nodes' => [] }, filename: 'menu.flow')).to be(false)
    end
  end

  describe '#import' do
    subject(:imported) { described_class.new(payload, filename: 'Menu principal.flow').import }

    it 'converts supported nodes, keeps positions and preserves valid edges' do
      expect(imported[:nodes].first).to include('id' => 'chat-1', 'type' => 'send_message', 'position' => { 'x' => 30.0, 'y' => 50.0 })
      expect(imported[:connections]).to contain_exactly(include('id' => 'valid', 'sourceHandle' => 'next'))
    end

    it 'marks external credentials and subflow dependencies without persisting secrets' do
      sheet = imported[:nodes].find { |node| node['id'] == 'sheet-1' }
      jump = imported[:nodes].find { |node| node['id'] == 'jump-1' }
      expect(sheet['data']).to include('requiresCredential' => true, 'apiKey' => nil)
      expect(jump.dig('data', 'pendingSubflow')).to eq('Rastrear pedido')
    end

    it 'retains unknown nodes as reviewable placeholders and reports invalid edges' do
      unknown = imported[:nodes].find { |node| node['id'] == 'custom-1' }
      expect(unknown).to include('type' => 'unsupported_imported_node', 'originalType' => 'oracleCustomOperation')
      expect(unknown.dig('data', 'originalData', 'password')).to be_nil
      expect(imported[:import_report]).to include('nodesUnsupported' => 1, 'connectionsInvalid' => 1)
    end

    it 'extracts flow variables with their correct scope' do
      expect(imported[:variables]).to include('name' => 'askedTimesMenu', 'scope' => 'workflow', 'defaultValue' => 0)
    end
  end
end
