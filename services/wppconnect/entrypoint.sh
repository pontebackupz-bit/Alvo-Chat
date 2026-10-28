#!/bin/sh
set -eu

# WPPConnect closes an unpaired browser after 60 seconds by default.  The
# inbox wizard fetches the QR asynchronously, so that short window can expire
# before it is shown and scanned.  Keep the session open until the user either
# scans it or explicitly replaces/removes the inbox connection.
config_file='/usr/src/wpp-server/dist/config.js'

node - "$config_file" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

if (!/autoClose\s*:/.test(source)) {
  const marker = /createOptions\s*:\s*\{/;
  const match = marker.exec(source);
  if (!match) {
    throw new Error(`Could not find createOptions in ${path}`);
  }

  source = `${source.slice(0, match.index)}${match[0]}\n        autoClose: 0,${source.slice(match.index + match[0].length)}`;
  fs.writeFileSync(path, source);
}
NODE

cd /usr/src/wpp-server
exec node dist/server.js
