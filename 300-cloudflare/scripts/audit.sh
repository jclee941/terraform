#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY_FILE="${SCRIPT_DIR}/../inventory/secrets.yaml"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Audit all secrets defined in inventory/secrets.yaml against actual targets
(GitHub repos, Vault paths, Cloudflare Secrets Store).

Options:
  --help    Show this help message

Required CLIs: yq, gh, vault, wrangler
EOF
  exit 0
}

[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && usage

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

require_cli() {
  local cli="$1"
  if ! command -v "$cli" >/dev/null 2>&1; then
    printf "%b❌ Missing required CLI: %s%b\n" "$RED" "$cli" "$NC" >&2
    exit 1
  fi
}

print_present() {
  printf "%b✅ present%b %s\n" "$GREEN" "$NC" "$1"
}

print_missing() {
  printf "%b❌ missing%b %s\n" "$RED" "$NC" "$1"
}

print_unknown() {
  printf "%b⚠️ unknown%b %s\n" "$YELLOW" "$NC" "$1"
}

check_github_secret() {
  local owner="$1"
  local repo="$2"
  local secret_name="$3"

  if gh secret list -R "${owner}/${repo}" | awk '{print $1}' | grep -Fx "$secret_name" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

check_vault_secret() {
  local mount="$1"
  local path="$2"
  local secret_name="$3"

  vault kv get -mount="$mount" -field="$secret_name" "$path" >/dev/null 2>&1
}

check_cf_secret() {
  local store_id="$1"
  local account_id="$2"
  local secret_name="$3"

  if wrangler secrets-store secret list --store-id "$store_id" --account-id "$account_id" | grep -F "${secret_name}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

require_cli yq
require_cli gh
require_cli vault
require_cli wrangler

if [ ! -f "$INVENTORY_FILE" ]; then
  printf "%b❌ missing%b inventory file: %s\n" "$RED" "$NC" "$INVENTORY_FILE" >&2
  exit 1
fi

owner="$(yq -r '.github.owner' "$INVENTORY_FILE")"
vault_mount="$(yq -r '.vault.mount' "$INVENTORY_FILE")"
store_id="$(yq -r '.store.id' "$INVENTORY_FILE")"
account_id="$(yq -r '.store.account_id' "$INVENTORY_FILE")"

missing_count=0

while IFS= read -r secret_name; do
  [ -z "$secret_name" ] && continue

  while IFS= read -r repo_alias; do
    [ -z "$repo_alias" ] && continue
    repo_name="$(yq -r ".github.repos.${repo_alias}" "$INVENTORY_FILE")"
    if check_github_secret "$owner" "$repo_name" "$secret_name"; then
      print_present "github:${owner}/${repo_name}:${secret_name}"
    else
      print_missing "github:${owner}/${repo_name}:${secret_name}"
      missing_count=$((missing_count + 1))
    fi
  done < <(yq -r ".secrets[] | select(.name == \"$secret_name\") | .targets.github[]?" "$INVENTORY_FILE")

  vault_path="$(yq -r ".secrets[] | select(.name == \"$secret_name\") | .targets.vault // \"\"" "$INVENTORY_FILE")"
  if [ -n "$vault_path" ]; then
    if check_vault_secret "$vault_mount" "$vault_path" "$secret_name"; then
      print_present "vault:${vault_mount}/${vault_path}:${secret_name}"
    else
      print_missing "vault:${vault_mount}/${vault_path}:${secret_name}"
      missing_count=$((missing_count + 1))
    fi
  fi

  if [ "$(yq -r ".secrets[] | select(.name == \"$secret_name\") | .targets.cf_store // false" "$INVENTORY_FILE")" = "true" ]; then
    if check_cf_secret "$store_id" "$account_id" "$secret_name"; then
      print_present "cf_store:${store_id}:${secret_name}"
    else
      print_missing "cf_store:${store_id}:${secret_name}"
      missing_count=$((missing_count + 1))
    fi
  fi

  if ! yq -e ".secrets[] | select(.name == \"$secret_name\") | .targets" "$INVENTORY_FILE" >/dev/null 2>&1; then
    print_unknown "targets-not-defined:${secret_name}"
  fi
done < <(yq -r '.secrets[].name' "$INVENTORY_FILE")

if [ "$missing_count" -gt 0 ]; then
  printf "%b❌ Audit failed%b: %d missing secret bindings\n" "$RED" "$NC" "$missing_count"
  exit 1
fi

printf "%b✅ Audit passed%b: all configured secret bindings were found\n" "$GREEN" "$NC"
