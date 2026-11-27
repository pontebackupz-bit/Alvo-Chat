# Implantação em produção

Esta configuração inicia o CRM em `http://192.168.1.164:8069`. Ela constrói uma imagem com o código deste repositório, incluindo o conector WhatsApp Baileys.

## Preparação do servidor

1. Copie o repositório para o servidor Docker.
2. Copie `docker-compose.production.env.example` para `.env` na raiz do repositório.
3. Substitua todos os valores `CHANGE_ME` por segredos fortes e pelas credenciais SMTP corporativas.
4. Não reutilize o `.env` de desenvolvimento e não envie o `.env` ao Git.

## Primeira inicialização

Execute na raiz do repositório:

```sh
docker compose -p crm-omnichannel -f docker-compose.production.yaml build
docker compose -p crm-omnichannel -f docker-compose.production.yaml run --rm rails bundle exec rails db:chatwoot_prepare
docker compose -p crm-omnichannel -f docker-compose.production.yaml up -d
```

Verifique o serviço:

```sh
curl -I http://192.168.1.164:8069/api
docker compose -p crm-omnichannel -f docker-compose.production.yaml ps
```

Os dados de PostgreSQL, Redis, anexos e sessões do Baileys ficam em volumes Docker persistentes. Inclua esses volumes no processo de backup do servidor.

## DNS e HTTPS

Quando o DNS estiver disponível, atualize `FRONTEND_URL` para a URL final. Se a infraestrutura publicar HTTPS por proxy reverso, ajuste `FORCE_SSL=true` e reinicie Rails e Sidekiq:

```sh
docker compose -p crm-omnichannel -f docker-compose.production.yaml up -d rails sidekiq
```

Um registro DNS não remove a porta `8069`. Para acessar sem informar a porta e usar HTTPS, o proxy reverso deve receber conexões em `80` e `443` e encaminhá-las para `192.168.1.164:8069`.

## Atualizações

Antes de iniciar uma nova imagem, execute novamente o preparo do banco:

```sh
docker compose -p crm-omnichannel -f docker-compose.production.yaml build
docker compose -p crm-omnichannel -f docker-compose.production.yaml run --rm rails bundle exec rails db:chatwoot_prepare
docker compose -p crm-omnichannel -f docker-compose.production.yaml up -d
```
