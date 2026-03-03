#!/bin/sh
# Entrypoint wrapper that applies runtime patches before starting MCPHub.
# Workaround for: https://github.com/samanhappy/mcphub/pull/654
# Remove this file after PR #654 merges and mcphub image version is bumped.

set -e

# Apply _placeholder sanitization patch
if [ -f /app/patches/patch-placeholder.cjs ]; then
  node /app/patches/patch-placeholder.cjs
fi

# Delegate to original entrypoint
exec /usr/local/bin/entrypoint.sh "$@"
