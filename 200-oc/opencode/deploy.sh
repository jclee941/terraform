#!/usr/bin/env bash
# deploy.sh — Generate and deploy OpenCode config to VM 200.
#
# Usage:
#   ./deploy.sh <variant>           # Generate + deploy
#   ./deploy.sh <variant> --dry-run # Generate + show diff, no deploy
#   ./deploy.sh <variant> --gen     # Generate only (no deploy)
#
# Variants: anti, claude, copilot
#
# What it does:
#   1. Runs generate.py to produce config files
#   2. Renames oh-my-opencode.json → .jsonc (VM runtime expects .jsonc)
#   3. Backs up current VM config
#   4. Deploys 3 files via rsync:
#      - opencode.jsonc
#      - oh-my-opencode.jsonc

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATED_DIR="${SCRIPT_DIR}/generated"

VM_HOST="192.168.50.200"
VM_USER="jclee"
VM_CONFIG_DIR="/home/${VM_USER}/.config/opencode"
SSH_OPTS="-o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new"

DEPLOY_FILES=(opencode.jsonc oh-my-opencode.jsonc)
VALID_VARIANTS=(anti claude copilot)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[deploy]${NC} $*"; }
warn() { echo -e "${YELLOW}[deploy]${NC} $*"; }
err()  { echo -e "${RED}[deploy]${NC} $*" >&2; }

usage() {
  echo "Usage: $0 <variant> [--dry-run|--gen]"
  echo "  Variants: ${VALID_VARIANTS[*]}"
  echo "  --dry-run  Generate and show diff, skip deploy"
  echo "  --gen      Generate only, skip deploy"
  exit 1
}

# --- Argument parsing ---
VARIANT=""
DRY_RUN=false
GEN_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --gen)     GEN_ONLY=true ;;
    -h|--help) usage ;;
    *)
      if [[ -z "$VARIANT" ]]; then
        VARIANT="$arg"
      else
        err "Unknown argument: $arg"
        usage
      fi
      ;;
  esac
done

[[ -z "$VARIANT" ]] && { err "Variant required."; usage; }

# Validate variant
valid=false
for v in "${VALID_VARIANTS[@]}"; do
  [[ "$v" == "$VARIANT" ]] && valid=true && break
done
$valid || { err "Invalid variant '$VARIANT'. Must be one of: ${VALID_VARIANTS[*]}"; exit 1; }

VARIANT_DIR="${GENERATED_DIR}/${VARIANT}"

# --- Step 1: Generate ---
log "Generating config for variant '${VARIANT}'..."
cd "$SCRIPT_DIR"
python3 -m gen.generate

if [[ ! -d "$VARIANT_DIR" ]]; then
  err "Generated directory not found: $VARIANT_DIR"
  exit 1
fi

# --- Step 2: Rename oh-my-opencode.json → .jsonc ---
if [[ -f "${VARIANT_DIR}/oh-my-opencode.json" ]]; then
  cp "${VARIANT_DIR}/oh-my-opencode.json" "${VARIANT_DIR}/oh-my-opencode.jsonc"
  log "Renamed oh-my-opencode.json → oh-my-opencode.jsonc"
fi

# Verify all deploy files exist
for f in "${DEPLOY_FILES[@]}"; do
  if [[ ! -f "${VARIANT_DIR}/${f}" ]]; then
    err "Missing generated file: ${VARIANT_DIR}/${f}"
    exit 1
  fi
done

log "Generated files:"
for f in "${DEPLOY_FILES[@]}"; do
  echo "  ${VARIANT_DIR}/${f}"
done

# --- Stop here if --gen ---
if $GEN_ONLY; then
  log "Generate-only mode. Done."
  exit 0
fi

# --- Step 3: Diff (always show) ---
echo ""
log "Comparing with VM config..."
DIFF_FOUND=false
for f in "${DEPLOY_FILES[@]}"; do
  LOCAL="${VARIANT_DIR}/${f}"
  REMOTE_CONTENT=$(ssh $SSH_OPTS "${VM_USER}@${VM_HOST}" "cat '${VM_CONFIG_DIR}/${f}' 2>/dev/null" || true)

  if [[ -z "$REMOTE_CONTENT" ]]; then
    warn "${f}: NEW file (does not exist on VM)"
    DIFF_FOUND=true
  else
    DIFF=$(diff <(echo "$REMOTE_CONTENT") "$LOCAL" 2>/dev/null || true)
    if [[ -n "$DIFF" ]]; then
      echo -e "${CYAN}--- ${f} ---${NC}"
      echo "$DIFF"
      DIFF_FOUND=true
    else
      log "${f}: no changes"
    fi
  fi
done

if ! $DIFF_FOUND; then
  log "No differences found. VM config is up to date."
  exit 0
fi

# --- Stop here if --dry-run ---
if $DRY_RUN; then
  warn "Dry-run mode. No files deployed."
  exit 0
fi

# --- Step 4: Backup ---
echo ""
BACKUP_TS=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="${VM_CONFIG_DIR}/.backup/${BACKUP_TS}"
log "Backing up current config → ${BACKUP_DIR}/"
ssh $SSH_OPTS "${VM_USER}@${VM_HOST}" "mkdir -p '${BACKUP_DIR}' && cp ${VM_CONFIG_DIR}/opencode.jsonc ${VM_CONFIG_DIR}/oh-my-opencode.jsonc '${BACKUP_DIR}/' 2>/dev/null || true"

# --- Step 5: Deploy ---
log "Deploying to ${VM_USER}@${VM_HOST}:${VM_CONFIG_DIR}/..."
for f in "${DEPLOY_FILES[@]}"; do
  rsync -az -e "ssh ${SSH_OPTS}" "${VARIANT_DIR}/${f}" "${VM_USER}@${VM_HOST}:${VM_CONFIG_DIR}/${f}"
done

# --- Step 6: Verify ---
echo ""
log "Verifying deployment..."
VERIFY_OK=true
for f in "${DEPLOY_FILES[@]}"; do
  LOCAL_HASH=$(sha256sum "${VARIANT_DIR}/${f}" | cut -d' ' -f1)
  REMOTE_HASH=$(ssh $SSH_OPTS "${VM_USER}@${VM_HOST}" "sha256sum '${VM_CONFIG_DIR}/${f}'" | cut -d' ' -f1)
  if [[ "$LOCAL_HASH" == "$REMOTE_HASH" ]]; then
    log "  ✓ ${f}"
  else
    err "  ✗ ${f} — hash mismatch!"
    VERIFY_OK=false
  fi
done

if $VERIFY_OK; then
  echo ""
  log "Deploy complete. Variant: ${VARIANT}, Backup: ${BACKUP_DIR}"
  echo -e "${YELLOW}[deploy]${NC} Note: OpenCode processes may need manual restart to pick up changes."
else
  err "Verification failed! Check files on VM."
  err "Rollback: ssh ${VM_USER}@${VM_HOST} 'cp ${BACKUP_DIR}/* ${VM_CONFIG_DIR}/'"
  exit 1
fi
