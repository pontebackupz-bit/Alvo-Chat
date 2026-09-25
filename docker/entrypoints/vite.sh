#!/bin/sh

set -x

rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

pnpm store prune
PNPM_CONFIRM_MODULES_PURGE=false pnpm install --frozen-lockfile

echo "Ready to run Vite development server."

exec "$@"
