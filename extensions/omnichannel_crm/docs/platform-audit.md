# Auditoria de plataforma

## Módulos encontrados

O Chatwoot fornece o núcleo omnichannel: autenticação, contas, usuários, equipes, contatos, empresas, conversas, mensagens, tags, notas, canais, notificações, relatórios, campanhas e configurações administrativas. A única extensão própria localizada é `omnichannel_crm`.

Essa extensão implementa leads, RBAC complementar, supervisão de equipes, distribuição, conexão n8n, regras de automação, execuções de workflow, indicadores comerciais e auditoria. Ela usa contatos, conversas, mensagens e equipes nativos como fonte de verdade.

## Lacunas encontradas e corrigidas

- A interface concentrava todas as áreas no grupo CRM. Leads, automações, distribuição e painel comercial agora possuem entradas próprias no sidebar; controle de acesso e auditoria ficam em Configurações.
- A atribuição de papéis existia apenas na API. A tela de controle de acesso passou a permitir atribuir e remover papéis.
- A auditoria do CRM existia apenas no backend. A tela de leitura foi adicionada.
- A API do CRM concatenava o ID da conta duas vezes. O cliente agora gera uma única URL por conta para todos os recursos, corrigindo auditoria, leads, n8n, automações, distribuição, papéis e dashboard.
- Os nomes de eventos apresentados no formulário foram alinhados com os eventos realmente emitidos pelo listener.
- O idioma padrão do Rails e do dashboard foi definido como `pt_BR`; há tradução completa do módulo próprio nesse locale.

## Limitações classificadas

Mantidas: rate limits, validações de dados, limites de upload, limites de lote e limites exigidos por provedores externos. Eles protegem segurança, disponibilidade ou integridade.

Comerciais removidas da experiência da plataforma: os bloqueios de interface e de rota para Funções Personalizadas, SLA e SAML foram retirados. Essas telas usam os controladores e modelos já presentes na instalação e continuam protegidas por permissões de administrador, validações de formulário e tratamento de erros. Cobrança continua fora da barra lateral local. O Capitão IA continua oculto quando o provedor correspondente não está configurado, pois não há funcionalidade local utilizável sem esse serviço externo.

O RBAC da extensão continua disponível em **Configurações > Controle de acesso CRM** e não depende da tela Enterprise de Funções Personalizadas. Ele cobre os papéis `administrator`, `supervisor` e `seller`, permissões, atribuições de papéis e responsáveis de equipes.

## Pendências de produto

- A regra CRM de vendedor/supervisor restringe as APIs da extensão, mas ainda não substitui o escopo da caixa de entrada nativa do Chatwoot. Alterar esse escopo exige uma mudança transversal de autorização nas conversas e testes de regressão de inbox.
- A tela n8n já lista workflows, histórico local e permite enfileirar uma execução manual. Falta somente a validação integrada contra uma instância n8n real, pois nenhuma foi configurada nesta instalação.
