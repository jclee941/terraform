#!/bin/sh
# Entrypoint wrapper that applies runtime patches before starting MCPHub.
# Origin: https://github.com/samanhappy/mcphub/pull/654 (closed without merge 2026-03-04)
# Permanent patch — upstream and MCP SDK do not handle _placeholder stripping.

set -e

# Apply _placeholder sanitization patch
if [ -f /app/patches/patch-placeholder.cjs ]; then
  node /app/patches/patch-placeholder.cjs
fi

# Delegate to original entrypoint
exec /usr/local/bin/entrypoint.sh "$@"
