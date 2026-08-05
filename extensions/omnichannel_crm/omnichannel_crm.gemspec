Gem::Specification.new do |spec|
  spec.name = 'omnichannel_crm'
  spec.version = '0.1.0'
  spec.summary = 'Modular CRM, RBAC and n8n extension for Chatwoot'
  spec.authors = ['CRM Omnichannel']
  spec.files = Dir['{app,config,db,lib}/**/*', 'README.md']
  spec.add_dependency 'rails', '>= 7.0'
end
