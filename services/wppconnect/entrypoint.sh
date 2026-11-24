#!/bin/sh
set -eu

# WPPConnect closes an unpaired browser after 60 seconds by default.  The
# inbox wizard fetches the QR asynchronously, so that short window can expire
# before it is shown and scanned. Give the operator a three-minute window; the
# application explicitly closes an abandoned wizard before creating another.
config_file='/usr/src/wpp-server/dist/config.js'

node - "$config_file" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

if (/autoClose\s*:/.test(source)) {
  source = source.replace(/autoClose\s*:\s*(?:false|\d+)\s*,?/, 'autoClose: 180000,');
  fs.writeFileSync(path, source);
} else {
  const marker = /createOptions\s*:\s*\{/;
  const match = marker.exec(source);
  if (!match) {
    throw new Error(`Could not find createOptions in ${path}`);
  }

  source = `${source.slice(0, match.index)}${match[0]}\n        autoClose: 180000,${source.slice(match.index + match[0].length)}`;
  fs.writeFileSync(path, source);
}

// WPPConnect registers `onMessage` before `onAnyMessage`. The former fires
// before the asynchronous media download has completed, which can make a
// webhook receive the previous attachment. Move only the `onmessage` webhook
// to the end of `onAnyMessage`, after autoDownload has handled this exact
// message. This is deliberately applied at container startup because the
// published WPPConnect image has no setting for that ordering.
const sessionUtilPath = path.replace(/config\.js$/, 'util/createSessionUtil.js');
const functionsPath = path.replace(/config\.js$/, 'util/functions.js');
let sessionUtil = fs.readFileSync(sessionUtilPath, 'utf8');
const receivedMessageMarker = "      req.io.emit('received-message', { response: message });";
const deferredWebhook = "      if (!message.fromMe) {\n        await (0, _functions.callWebHook)(client, req, 'onmessage', message);\n      }\n";

// Formatting has changed across WPPConnect releases. Match the actual call
// instead of one compiled indentation layout, otherwise the container starts
// with the old early webhook and media from a previous event is published.
// Only a line that *starts* with the call is the early webhook: the deferred
// one added below reads `await (0, ...)` and must survive later restarts.
const earlyWebhook = /\n[ \t]*\(0, _functions\.callWebHook\)\(client, req, 'onmessage', message\);[ \t]*\n/;

// A restarted container keeps its patched files, so this must be safe to run
// again: patching twice used to strip the deferred call, leave a dangling
// `await`, and WPPConnect then crashed on every start.
if (sessionUtil.includes(deferredWebhook)) {
  // Already patched by a previous start of this container.
} else if (earlyWebhook.test(sessionUtil)) {
  if (!sessionUtil.includes(receivedMessageMarker)) {
    throw new Error(`Could not find the WPPConnect message delivery marker in ${sessionUtilPath}`);
  }

  sessionUtil = sessionUtil.replace(earlyWebhook, '\n');
  sessionUtil = sessionUtil.replace(receivedMessageMarker, `${deferredWebhook}${receivedMessageMarker}`);
  fs.writeFileSync(sessionUtilPath, sessionUtil);
} else {
  // Fail visibly after an upstream image format change rather than starting a
  // server that silently reintroduces stale-media webhooks.
  throw new Error(`Could not patch WPPConnect webhook ordering in ${sessionUtilPath}`);
}

// Some stickers arrive from WhatsApp without `isMedia`, `isMMS` or a MIME
// type. Upstream then skips autoDownload altogether even though decryptFile
// supports the message. Treat all supported inbound attachment types as media
// so the deferred webhook above always carries the current file bytes.
let functions = fs.readFileSync(functionsPath, 'utf8');
const upstreamMediaGuard = "message && (message['mimetype'] || message.isMedia || message.isMMS)";
const mediaTypes = "['sticker', 'image', 'gif', 'video', 'audio', 'ptt', 'document'].includes(message.type)";
const patchedMediaGuard = `message && (message['mimetype'] || message.isMedia || message.isMMS || ${mediaTypes})`;

if (functions.includes(upstreamMediaGuard)) {
  functions = functions.replace(upstreamMediaGuard, patchedMediaGuard);
  fs.writeFileSync(functionsPath, functions);
} else if (!functions.includes(patchedMediaGuard)) {
  throw new Error(`Could not patch WPPConnect media detection in ${functionsPath}`);
}
NODE

cd /usr/src/wpp-server

# Chromium leaves Singleton* lock files in each session profile, stamped with
# the container's hostname. The profiles live in a volume, so after the
# container is recreated Chromium sees the old lock, decides the profile is
# "in use by another computer" and refuses to start: every number stays
# offline. No browser runs yet at this point, so the locks are stale.
find /usr/src/wpp-server/userDataDir -maxdepth 2 -name 'Singleton*' -exec rm -f {} + 2>/dev/null || true

# alvochat-server.js starts the same server with the onselfmessage webhook on,
# so messages typed on the connected phone reach AlvoChat.
exec node alvochat-server.js
