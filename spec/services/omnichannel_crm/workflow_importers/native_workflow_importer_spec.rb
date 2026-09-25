require 'rails_helper'

RSpec.describe OmnichannelCrm::WorkflowImporters::NativeWorkflowImporter do
  let(:payload) do
    {
      'schema' => 'comercial-alvorada.workflow', 'version' => 1,
      'workflow' => { 'name' => 'Fluxo Alvo', 'nodes' => [{ 'id' => 'start', 'type' => 'start', 'data' => {} }],
                      'connections' => [], 'variables' => [], 'metadata' => {} }
    }
  end

  it 'detects and imports the native .alvo schema' do
    expect(described_class.can_import?(payload, filename: 'fluxo.alvo')).to be(true)
    imported = described_class.new(payload, filename: 'fluxo.alvo').import
    expect(imported).to include(name: 'Fluxo Alvo', source: 'native')
    expect(imported[:nodes]).to eq(payload['workflow']['nodes'])
  end
end
