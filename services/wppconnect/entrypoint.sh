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
NODE

cd /usr/src/wpp-server
exec node dist/server.js
