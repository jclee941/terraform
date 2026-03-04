#!/usr/bin/env bash
set -euo pipefail

# 1Password → GitHub Secret Sync
# Pulls secrets from 1Password and registers them as GitHub Actions secrets.
# Supports: audit, dry-run, selective sync, and rotation.
#
# Usage:
#   scripts/sync-vault-secrets.sh              # Sync all from 1Password
#   scripts/sync-vault-secrets.sh --audit      # Check only, no changes
#   scripts/sync-vault-secrets.sh --dry-run    # Show what would be set
#   scripts/sync-vault-secrets.sh --force      # Overwrite existing secrets

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

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Sync secrets from 1Password to GitHub Actions for ${REPO}.

Options:
  --audit        Check which secrets need sync (no changes)
  --dry-run      Show what would be set without applying
  --force        Overwrite existing secrets (for rotation)
  -h, --help     Show this help

Environment:
  OP_SERVICE_ACCOUNT_TOKEN  1Password service account token (required)

1Password Paths:
  op://homelab/cloudflare/secrets  → Account ID
  op://homelab/grafana/secrets     → Service account token
  op://homelab/github/secrets      → Personal access token
  op://homelab/n8n/secrets         → Webhook config
  op://homelab/supabase/secrets    → URL and service key
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

if ! command -v op >/dev/null 2>&1; then
  printf "${RED}op CLI required. Install: https://developer.1password.com/docs/cli/get-started/${NC}\n" >&2
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

# --- Verify 1Password connectivity ---

if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
  printf "${RED}OP_SERVICE_ACCOUNT_TOKEN not set${NC}\n" >&2
  printf "Set via: export OP_SERVICE_ACCOUNT_TOKEN='ops_xxx'\n" >&2
  exit 1
fi

if ! op whoami &>/dev/null; then
  printf "${RED}1Password authentication failed${NC}\n" >&2
  printf "Check OP_SERVICE_ACCOUNT_TOKEN\n" >&2
  exit 1
fi

# --- Secret mapping: GitHub secret name → 1Password reference ---
# Format: "GITHUB_SECRET_NAME|op://homelab/item/secrets/field|priority|description"

OP_SECRETS=(
  "TF_VAR_GRAFANA_AUTH|op://homelab/grafana/secrets/service_account_token|P1|Grafana service account token"
  "TF_VAR_GITHUB_TOKEN|op://homelab/github/secrets/personal_access_token|P1|GitHub PAT for TF provider"
  "TF_VAR_SUPABASE_URL|op://homelab/supabase/secrets/url|P1|Supabase project URL"
  "GH_PAT|op://homelab/github/secrets/personal_access_token|P2|GitHub PAT for workflow automation"
)

# Derived secrets (not from 1Password, from known infrastructure)
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

printf "${BOLD}1Password → GitHub Secret Sync${NC}\n"
printf "Repo:   %s\n\n" "$REPO"

synced=0
skipped=0
failed=0
total=0

# Process 1Password-sourced secrets
for entry in "${OP_SECRETS[@]}"; do
  IFS='|' read -r name op_ref priority _ <<< "$entry"
  (( ++total ))

  # Check if already configured (skip unless --force)
  if is_configured "$name" && ! $FORCE; then
    printf "${GREEN}  [OK]${NC} %-35s %s  (already set)\n" "$name" "$priority"
    (( ++skipped ))
    continue
  fi

  # Fetch from 1Password
  value="$(op read "$op_ref" 2>/dev/null)" || true

  if [[ -z "$value" ]]; then
    printf "${RED}  [!!]${NC} %-35s %s  1Password ref missing: %s\n" "$name" "$priority" "$op_ref"
    (( ++failed ))
    continue
  fi

  if [[ "$value" =~ ^[Pp][Ll][Aa][Cc][Ee][Hh][Oo][Ll][Dd][Ee][Rr] ]] || [[ "$value" == "PLACEHOLDER_NEEDS_REAL_TOKEN" ]]; then
    printf "${YELLOW}  [PH]${NC} %-35s %s  placeholder value — skipped\n" "$name" "$priority"
    (( ++skipped ))
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
      printf "\n${BOLD}Manual secrets (not in 1Password):${NC}\n"
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
