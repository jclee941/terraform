#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY_FILE="${SCRIPT_DIR}/../inventory/secrets.yaml"

DRY_RUN=false
TARGET="all"
SECRET_FILTER=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat <<EOF
Usage: $(basename "$0") [--dry-run] [--target cf|github|vault|all] [--secret SECRET_NAME]

Options:
  --dry-run            Print actions without applying changes
  --target TARGET      One of: cf, github, vault, all (default: all)
  --secret NAME        Sync only one secret by name
  -h, --help           Show this help
EOF
}

log() {
  printf "%b%s%b\n" "$BLUE" "$1" "$NC"
}

ok() {
  printf "%b%s%b\n" "$GREEN" "$1" "$NC"
}

warn() {
  printf "%b%s%b\n" "$YELLOW" "$1" "$NC"
}

err() {
  printf "%b%s%b\n" "$RED" "$1" "$NC" >&2
}

require_cli() {
  local cli="$1"
  if ! command -v "$cli" >/dev/null 2>&1; then
    err "Missing required CLI: ${cli}"
    exit 1
  fi
}

run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    printf "[DRY-RUN] %s\n" "$*"
  else
    eval "$@"
  fi
}

read_secret_value() {
  local secret_name="$1"
  local vault_path="$2"
  local vault_mount
  local value

  vault_mount="$(yq -r '.vault.mount' "$INVENTORY_FILE")"

  if [ -n "$vault_path" ]; then
    if value="$(vault kv get -mount="$vault_mount" -field="$secret_name" "$vault_path" 2>/dev/null)"; then
      printf "%s" "$value"
      return 0
    fi
  fi

  warn "Enter value for ${secret_name}:"
  read -r -s value
  printf "\n"
  printf "%s" "$value"
}

sync_cf_secret() {
  local secret_name="$1"
  local secret_value="$2"
  local store_id account_id cmd

  store_id="$(yq -r '.store.id' "$INVENTORY_FILE")"
  account_id="$(yq -r '.store.account_id' "$INVENTORY_FILE")"

  cmd="printf '%s' \"$secret_value\" | wrangler secrets-store secret create \"$secret_name\" --store-id \"$store_id\" --account-id \"$account_id\" --remote"
  run_cmd "$cmd"
}

sync_github_secret() {
  local secret_name="$1"
  local secret_value="$2"
  local owner repo_alias repo_name cmd

  owner="$(yq -r '.github.owner' "$INVENTORY_FILE")"
  while IFS= read -r repo_alias; do
    [ -z "$repo_alias" ] && continue
    repo_name="$(yq -r ".github.repos.${repo_alias}" "$INVENTORY_FILE")"
    cmd="gh secret set \"$secret_name\" -R \"$owner/$repo_name\" -b \"$secret_value\""
    run_cmd "$cmd"
  done < <(yq -r ".secrets[] | select(.name == \"$secret_name\") | .targets.github[]?" "$INVENTORY_FILE")
}

sync_vault_secret() {
  local secret_name="$1"
  local secret_value="$2"
  local vault_mount vault_path cmd

  vault_mount="$(yq -r '.vault.mount' "$INVENTORY_FILE")"
  vault_path="$(yq -r ".secrets[] | select(.name == \"$secret_name\") | .targets.vault // \"\"" "$INVENTORY_FILE")"

  [ -z "$vault_path" ] && return 0
  cmd="vault kv patch -mount=\"$vault_mount\" \"$vault_path\" \"$secret_name=$secret_value\""
  run_cmd "$cmd"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    --target)
      TARGET="${2:-}"
      shift
      ;;
    --secret)
      SECRET_FILTER="${2:-}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

require_cli yq

case "$TARGET" in
  cf)
    require_cli wrangler
    ;;
  github)
    require_cli gh
    ;;
  vault)
    require_cli vault
    ;;
  all)
    require_cli wrangler
    require_cli gh
    require_cli vault
    ;;
  *)
    err "Invalid --target value: $TARGET"
    exit 1
    ;;
esac

if [ ! -f "$INVENTORY_FILE" ]; then
  err "Inventory file not found: $INVENTORY_FILE"
  exit 1
fi

mapfile -t secrets < <(yq -r '.secrets[].name' "$INVENTORY_FILE")

if [ -n "$SECRET_FILTER" ]; then
  secrets=("$SECRET_FILTER")
fi

total="${#secrets[@]}"
index=0

log "Starting sync: target=${TARGET}, dry-run=${DRY_RUN}, secrets=${total}"

for secret_name in "${secrets[@]}"; do
  index=$((index + 1))
  printf "[%d/%d] Processing %s\n" "$index" "$total" "$secret_name"

  vault_path="$(yq -r ".secrets[] | select(.name == \"$secret_name\") | .targets.vault // \"\"" "$INVENTORY_FILE")"
  secret_value="$(read_secret_value "$secret_name" "$vault_path")"

  if [ -z "$secret_value" ]; then
    warn "Skipping ${secret_name}: empty value"
    continue
  fi

  if [ "$TARGET" = "cf" ] || [ "$TARGET" = "all" ]; then
    if [ "$(yq -r ".secrets[] | select(.name == \"$secret_name\") | .targets.cf_store // false" "$INVENTORY_FILE")" = "true" ]; then
      log "Syncing ${secret_name} -> Cloudflare Secrets Store"
      sync_cf_secret "$secret_name" "$secret_value"
    fi
  fi

  if [ "$TARGET" = "github" ] || [ "$TARGET" = "all" ]; then
    if yq -e ".secrets[] | select(.name == \"$secret_name\") | .targets.github" "$INVENTORY_FILE" >/dev/null 2>&1; then
      log "Syncing ${secret_name} -> GitHub Actions secrets"
      sync_github_secret "$secret_name" "$secret_value"
    fi
  fi

  if [ "$TARGET" = "vault" ] || [ "$TARGET" = "all" ]; then
    if [ -n "$vault_path" ]; then
      log "Syncing ${secret_name} -> Vault"
      sync_vault_secret "$secret_name" "$secret_value"
    fi
  fi

  ok "Done: ${secret_name}"
done

ok "Sync completed."
