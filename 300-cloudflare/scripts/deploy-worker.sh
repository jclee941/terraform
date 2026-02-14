#!/usr/bin/env bash
# Usage: ./scripts/deploy-worker.sh [worker-name]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CF_DIR="$(dirname "$SCRIPT_DIR")"
WORKER_NAME="${1:-synology-proxy}"
WORKER_DIR="${CF_DIR}/workers/${WORKER_NAME}"

if [[ ! -d "$WORKER_DIR" ]]; then
  echo "ERROR: Worker directory not found: $WORKER_DIR"
  ls -1 "${CF_DIR}/workers/" 2>/dev/null || echo "  (none)"
  exit 1
fi

echo "=== Deploying Worker: ${WORKER_NAME} ==="

cd "$WORKER_DIR"
npm ci --silent 2>/dev/null || npm install --silent

echo "→ Type checking..."
npm run type-check

echo "→ Running tests..."
npm test

echo "→ Deploying to Cloudflare..."
npx wrangler deploy

echo "=== ✅ Worker '${WORKER_NAME}' deployed ==="
