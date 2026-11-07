#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# shortcut: build only the native bindings this demo uses; rebuild any new native connector before extending the workflow.
npm ci --prefix server --ignore-scripts --cache .runtime/npm --no-fund --no-audit
npm rebuild --prefix server sqlite3 isolated-vm --cache .runtime/npm
node -e 'require("./server/node_modules/sqlite3"); require("./server/node_modules/isolated-vm"); console.log("Recovery native bindings ready")'
