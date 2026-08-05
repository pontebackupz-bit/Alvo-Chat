# Conector WhatsApp por sessão (Baileys)

> **Atenção:** esta é uma conexão não oficial baseada no WhatsApp Web. O uso pode resultar em bloqueio ou restrição do número pelo WhatsApp. Use apenas números autorizados, atendimento humano e mensagens solicitadas. O serviço não oferece disparo em massa.

## Teste local

1. Inicie o serviço: `docker compose up -d --build baileys`.
2. Crie uma sessão:

```sh
curl -X POST http://localhost:3001/sessions -H "Authorization: Bearer local-development-token-change-before-production" -H "Content-Type: application/json" -d '{"session_id":"vendas-teste"}'
```

3. Consulte o QR Code até o campo `qr` ser preenchido:

```sh
curl http://localhost:3001/sessions/vendas-teste -H "Authorization: Bearer local-development-token-change-before-production"
```

Abra o valor `qr` (data URL) no navegador e faça a leitura em **WhatsApp > Dispositivos conectados**. Para produção, defina um `BAILEYS_API_TOKEN` forte no ambiente e mantenha o volume `baileys_data`.
