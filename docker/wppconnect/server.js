// Starts wppconnect-server with its bundled config, enabling the
// `onselfmessage` webhook so messages typed on the connected phone (or another
// linked device) reach AlvoChat. The option has no environment variable.
const config = require('./dist/config').default;
const { initServer } = require('./dist/index');

initServer({ ...config, webhook: { ...config.webhook, onSelfMessage: true } });
