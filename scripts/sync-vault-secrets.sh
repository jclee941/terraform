#!/usr/bin/env bash
set -euo pipefail

# Vault → GitHub Secret Sync
# Pulls secrets from HashiCorp Vault and registers them as GitHub Actions secrets.
# Supports: audit, dry-run, selective sync, and rotation.
#
# Usage:
#   scripts/sync-vault-secrets.sh              # Sync all from Vault
#   scripts/sync-vault-secrets.sh --audit      # Check only, no changes
#   scripts/sync-vault-secrets.sh --dry-run    # Show what would be set
#   scripts/sync-vault-secrets.sh --force      # Overwrite existing secrets

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO="qws941/terraform"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

DRY_RUN=false
AUDIT_ONLY=false
FORCE=false

VAULT_ADDR="${VAULT_ADDR:-http://192.168.50.112:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Sync secrets from HashiCorp Vault to GitHub Actions for ${REPO}.

Options:
  --audit        Check which secrets need sync (no changes)
  --dry-run      Show what would be set without applying
  --force        Overwrite existing secrets (for rotation)
  -h, --help     Show this help

Environment:
  VAULT_ADDR     Vault address (default: http://192.168.50.112:8200)
  VAULT_TOKEN    Vault token (required, or read from 100-pve/terraform.tfvars)

Vault Paths:
  secret/homelab/cloudflare  → R2 credentials, account ID
  secret/homelab/grafana     → Service account token
  secret/homelab/github      → Personal access token
  secret/homelab/n8n         → Webhook config
  secret/homelab/supabase    → URL and service key
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)   DRY_RUN=true ;;
    --audit)     AUDIT_ONLY=true ;;
    --force)     FORCE=true ;;
    -h|--help)   usage; exit 0 ;;
    *)           printf "${RED}Unknown: %s${NC}\n" "$1" >&2; usage; exit 1 ;;
  esac
  shift
done

# --- Dependency checks ---

if ! command -v vault >/dev/null 2>&1; then
  printf "${RED}vault CLI required. Install: https://developer.hashicorp.com/vault/install${NC}\n" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  printf "${RED}gh CLI required. Install: https://cli.github.com/${NC}\n" >&2
  exit 1
fi

if ! gh auth status &>/dev/null; then
  printf "${RED}gh auth required — run: gh auth login${NC}\n" >&2
  exit 1
fi

# --- Resolve Vault token ---

if [[ -z "$VAULT_TOKEN" ]]; then
  TFVARS_PVE="$ROOT_DIR/100-pve/terraform.tfvars"
  if [[ -f "$TFVARS_PVE" ]]; then
    VAULT_TOKEN="$(grep -E '^\s*vault_token\s*=' "$TFVARS_PVE" | sed 's/.*=\s*"\?\([^"]*\)"\?/\1/' | tr -d '[:space:]')"
  fi
fi

if [[ -z "$VAULT_TOKEN" ]]; then
  printf "${RED}VAULT_TOKEN not set and not found in terraform.tfvars${NC}\n" >&2
  printf "Set via: export VAULT_TOKEN='hvs.xxx'\n" >&2
  exit 1
fi

export VAULT_ADDR VAULT_TOKEN

# --- Verify Vault connectivity ---

if ! vault token lookup &>/dev/null; then
  printf "${RED}Vault authentication failed at %s${NC}\n" "$VAULT_ADDR" >&2
  printf "Check VAULT_ADDR and VAULT_TOKEN\n" >&2
  exit 1
fi

# --- Secret mapping: GitHub secret name → Vault path + field ---
# Format: "GITHUB_SECRET_NAME|vault_path|vault_field|priority|description"

VAULT_SECRETS=(
  "AWS_ACCESS_KEY_ID|secret/homelab/cloudflare|r2_access_key_id|P0|R2 S3-compatible access key"
  "AWS_SECRET_ACCESS_KEY|secret/homelab/cloudflare|r2_secret_access_key|P0|R2 S3-compatible secret"
  "TF_VAR_GRAFANA_AUTH|secret/homelab/grafana|service_account_token|P1|Grafana service account token"
  "TF_VAR_GITHUB_TOKEN|secret/homelab/github|personal_access_token|P1|GitHub PAT for TF provider"
  "TF_VAR_SUPABASE_URL|secret/homelab/supabase|url|P1|Supabase project URL"
  "GH_PAT|secret/homelab/github|personal_access_token|P2|GitHub PAT for workflow automation"
)

# Derived secrets (not from Vault, from known infrastructure)
DERIVED_SECRETS=(
  "TF_VAR_N8N_WEBHOOK_URL|http://192.168.50.112:5678/webhook|P1|n8n webhook base URL"
)

# --- Fetch existing secrets ---

existing_secrets=()
while IFS= read -r line; do
  [[ -n "$line" ]] && existing_secrets+=("$(echo "$line" | awk '{print $1}')")
done < <(gh secret list -R "$REPO" 2>/dev/null)

is_configured() {
  local name="$1"
  for s in "${existing_secrets[@]+"${existing_secrets[@]}"}"; do
    [[ "$s" == "$name" ]] && return 0
  done
  return 1
}

mask_value() {
  local v="$1"
  local len=${#v}
  if (( len <= 4 )); then echo "****"
  elif (( len <= 8 )); then echo "${v:0:2}****"
  else echo "${v:0:4}...${v: -2}"
  fi
}

# --- Main sync logic ---

printf "${BOLD}Vault → GitHub Secret Sync${NC}\n"
printf "Vault:  %s\n" "$VAULT_ADDR"
printf "Repo:   %s\n\n" "$REPO"

synced=0
skipped=0
failed=0
total=0

# Process Vault-sourced secrets
for entry in "${VAULT_SECRETS[@]}"; do
  IFS='|' read -r name path field priority _ <<< "$entry"
  (( ++total ))

  # Check if already configured (skip unless --force)
  if is_configured "$name" && ! $FORCE; then
    printf "${GREEN}  [OK]${NC} %-35s %s  (already set)\n" "$name" "$priority"
    (( ++skipped ))
    continue
  fi

  # Fetch from Vault
  value="$(vault kv get -field="$field" "$path" 2>/dev/null)" || true

  if [[ -z "$value" ]]; then
    printf "${RED}  [!!]${NC} %-35s %s  Vault field missing: %s → %s\n" "$name" "$priority" "$path" "$field"
    (( ++failed ))
    continue
  fi

  if $AUDIT_ONLY; then
    if is_configured "$name"; then
      printf "${YELLOW}  [~~]${NC} %-35s %s  would rotate: %s\n" "$name" "$priority" "$(mask_value "$value")"
    else
      printf "${YELLOW}  [--]${NC} %-35s %s  available: %s\n" "$name" "$priority" "$(mask_value "$value")"
    fi
    continue
  fi

  if $DRY_RUN; then
    local_action="set"
    is_configured "$name" && local_action="rotate"
    printf "${BLUE}  [DRY]${NC} %-35s %s  would %s: %s\n" "$name" "$priority" "$local_action" "$(mask_value "$value")"
    continue
  fi

  # Set the secret
  if printf "%s" "$value" | gh secret set "$name" -R "$REPO" 2>/dev/null; then
    local_action="SET"
    is_configured "$name" && $FORCE && local_action="ROTATED"
    printf "${GREEN}  [${local_action}]${NC} %-35s %s\n" "$name" "$priority"
    (( ++synced ))
  else
    printf "${RED}  [ERR]${NC} %-35s %s  gh secret set failed\n" "$name" "$priority"
    (( ++failed ))
  fi
done

# Process derived secrets (known infrastructure values)
for entry in "${DERIVED_SECRETS[@]}"; do
  IFS='|' read -r name value priority _ <<< "$entry"
  (( ++total ))

  if is_configured "$name" && ! $FORCE; then
    printf "${GREEN}  [OK]${NC} %-35s %s  (already set)\n" "$name" "$priority"
    (( ++skipped ))
    continue
  fi

  if $AUDIT_ONLY; then
    if is_configured "$name"; then
      printf "${YELLOW}  [~~]${NC} %-35s %s  derived: %s\n" "$name" "$priority" "$(mask_value "$value")"
    else
      printf "${YELLOW}  [--]${NC} %-35s %s  derived: %s\n" "$name" "$priority" "$(mask_value "$value")"
    fi
    continue
  fi

  if $DRY_RUN; then
    printf "${BLUE}  [DRY]${NC} %-35s %s  derived: %s\n" "$name" "$priority" "$(mask_value "$value")"
    continue
  fi

  if printf "%s" "$value" | gh secret set "$name" -R "$REPO" 2>/dev/null; then
    printf "${GREEN}  [SET]${NC} %-35s %s\n" "$name" "$priority"
    (( ++synced ))
  else
    printf "${RED}  [ERR]${NC} %-35s %s  gh secret set failed\n" "$name" "$priority"
    (( ++failed ))
  fi
done

# --- Summary ---

printf "\n${BOLD}Summary:${NC} %d total" "$total"
if $AUDIT_ONLY; then
  printf " (audit mode)\n"
elif $DRY_RUN; then
  printf " (dry-run)\n"
else
  printf ", ${GREEN}%d synced${NC}, %d skipped, ${RED}%d failed${NC}\n" "$synced" "$skipped" "$failed"
fi

# --- Report remaining manual secrets ---

MANUAL_SECRETS=(
  "TF_API_TOKEN|P0|Terraform Cloud (skip if not using TFC)"
  "CF_ACCESS_CLIENT_ID|P2|CF Zero Trust → Service Tokens"
  "CF_ACCESS_CLIENT_SECRET|P2|CF Zero Trust → Service Tokens"
)

manual_count=0
for entry in "${MANUAL_SECRETS[@]}"; do
  IFS='|' read -r name priority source <<< "$entry"
  if ! is_configured "$name"; then
    if (( manual_count == 0 )); then
      printf "\n${BOLD}Manual secrets (not in Vault):${NC}\n"
    fi
    printf "  ${YELLOW}%-35s${NC} %s  %s\n" "$name" "$priority" "$source"
    (( ++manual_count ))
  fi
done

if (( manual_count > 0 )); then
  printf "\nSet manually: ${CYAN}gh secret set NAME -R %s${NC}\n" "$REPO"
fi

if (( failed > 0 )); then
  exit 1
fi
