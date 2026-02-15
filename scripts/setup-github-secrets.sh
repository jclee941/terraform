#!/usr/bin/env bash
set -euo pipefail

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
PRIORITY_FILTER=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Register GitHub Actions secrets for ${REPO} from local .tfvars files.

Options:
  --dry-run          Show what would be set without applying
  --audit            Only check which secrets are missing (no prompts)
  --priority P       Filter by priority: P0, P1, P2
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)   DRY_RUN=true ;;
    --audit)     AUDIT_ONLY=true ;;
    --priority)  PRIORITY_FILTER="$2"; shift ;;
    -h|--help)   usage; exit 0 ;;
    *)           printf "${RED}Unknown: %s${NC}\n" "$1" >&2; usage; exit 1 ;;
  esac
  shift
done

if ! command -v gh >/dev/null 2>&1; then
  printf "${RED}gh CLI required${NC}\n" >&2
  exit 1
fi

if ! gh auth status &>/dev/null; then
  printf "${RED}gh auth required — run: gh auth login${NC}\n" >&2
  exit 1
fi

TFVARS_PVE="$ROOT_DIR/100-pve/terraform.tfvars"
TFVARS_CF="$ROOT_DIR/300-cloudflare/terraform.tfvars"

declare -A LOCAL_VALUES

parse_tfvars() {
  local file="$1"
  [[ ! -f "$file" ]] && return
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*) ]]; then
      local key="${BASH_REMATCH[1]}"
      local val="${BASH_REMATCH[2]}"
      val="${val#\"}" ; val="${val%\"}"
      val="${val#\'}" ; val="${val%\'}"
      val="$(echo "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [[ -n "$val" ]] && LOCAL_VALUES["$key"]="$val"
    fi
  done < "$file"
}

parse_tfvars "$TFVARS_PVE"
parse_tfvars "$TFVARS_CF"

declare -A SECRET_MAP
declare -A SECRET_PRIORITY
declare -A SECRET_SOURCE

register() {
  local name="$1" priority="$2" source="$3"
  SECRET_MAP["$name"]=1
  SECRET_PRIORITY["$name"]="$priority"
  SECRET_SOURCE["$name"]="$source"
}

register AWS_ACCESS_KEY_ID        P0 "env:AWS_ACCESS_KEY_ID"
register AWS_SECRET_ACCESS_KEY    P0 "env:AWS_SECRET_ACCESS_KEY"
register TF_API_TOKEN             P0 "env:TF_API_TOKEN"
register TF_VAR_PROXMOX_ENDPOINT  P0 "tfvars:100-pve:proxmox_endpoint"
register TF_VAR_PROXMOX_API_TOKEN P0 "tfvars:100-pve:proxmox_api_token"
register TF_VAR_PROXMOX_INSECURE  P0 "tfvars:100-pve:proxmox_insecure"

register TF_VAR_GRAFANA_AUTH          P1 "env:GRAFANA_AUTH"
register TF_VAR_N8N_WEBHOOK_URL       P1 "env:N8N_WEBHOOK_URL"
register TF_VAR_SUPABASE_URL          P1 "env:SUPABASE_URL"
register TF_VAR_CLOUDFLARE_ACCOUNT_ID P1 "tfvars:300-cloudflare:cloudflare_account_id"
register TF_VAR_CLOUDFLARE_ZONE_ID    P1 "tfvars:300-cloudflare:cloudflare_zone_id"
register TF_VAR_SYNOLOGY_DOMAIN       P1 "tfvars:300-cloudflare:synology_domain"
register TF_VAR_ACCESS_ALLOWED_EMAILS P1 "tfvars:300-cloudflare:access_allowed_emails"
register TF_VAR_GITHUB_TOKEN          P1 "env:GITHUB_TOKEN"
register TF_VAR_VAULT_TOKEN           P1 "tfvars:100-pve:vault_token"

register CLOUDFLARE_API_TOKEN    P2 "env:CLOUDFLARE_API_TOKEN"
register CLOUDFLARE_ACCOUNT_ID   P2 "tfvars:300-cloudflare:cloudflare_account_id"
register GH_PAT                  P2 "env:GH_PAT"
register CF_ACCESS_CLIENT_ID     P2 "env:CF_ACCESS_CLIENT_ID"
register CF_ACCESS_CLIENT_SECRET P2 "env:CF_ACCESS_CLIENT_SECRET"

resolve_value() {
  local name="$1"
  local source="${SECRET_SOURCE[$name]}"
  local type="${source%%:*}"
  local rest="${source#*:}"

  case "$type" in
    tfvars)
      local var_name="${rest##*:}"
      printf "%s" "${LOCAL_VALUES[$var_name]:-}"
      ;;
    env)
      local env_var="${rest}"
      printf "%s" "${!env_var:-}"
      ;;
  esac
}

tfvar_to_secret_name() {
  local name="$1"
  if [[ "$name" == TF_VAR_* ]]; then
    local var_part="${name#TF_VAR_}"
    printf "%s" "$(echo "$var_part" | tr '[:upper:]' '[:lower:]')"
  fi
}

try_resolve_from_tfvars() {
  local name="$1"
  local lower_name
  lower_name="$(tfvar_to_secret_name "$name")"
  [[ -z "$lower_name" ]] && return
  printf "%s" "${LOCAL_VALUES[$lower_name]:-}"
}

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

printf "${BOLD}GitHub Actions Secret Manager — %s${NC}\n\n" "$REPO"

missing=0
configured=0
resolvable=0
total=0

sorted_secrets=()
for name in "${!SECRET_MAP[@]}"; do
  sorted_secrets+=("$name")
done
mapfile -t sorted_secrets < <(printf '%s\n' "${sorted_secrets[@]}" | sort)

for name in "${sorted_secrets[@]}"; do
  priority="${SECRET_PRIORITY[$name]}"

  if [[ -n "$PRIORITY_FILTER" && "$priority" != "$PRIORITY_FILTER" ]]; then
    continue
  fi

  (( ++total ))

  if is_configured "$name"; then
    (( ++configured ))
    printf "${GREEN}  [OK]${NC} %-35s %s\n" "$name" "$priority"
    continue
  fi

  value="$(resolve_value "$name")"
  [[ -z "$value" ]] && value="$(try_resolve_from_tfvars "$name")"

  if [[ -n "$value" ]]; then
    (( ++resolvable ))
    printf "${YELLOW}  [--]${NC} %-35s %s  ${CYAN}value: %s${NC}\n" "$name" "$priority" "$(mask_value "$value")"
  else
    (( ++missing ))
    printf "${RED}  [!!]${NC} %-35s %s  ${RED}source: %s${NC}\n" "$name" "$priority" "${SECRET_SOURCE[$name]}"
  fi
done

printf "\n${BOLD}Summary:${NC} %d total, ${GREEN}%d configured${NC}, ${YELLOW}%d resolvable${NC}, ${RED}%d manual${NC}\n\n" \
  "$total" "$configured" "$resolvable" "$missing"

if $AUDIT_ONLY; then
  [[ $((missing + resolvable)) -gt 0 ]] && exit 1
  exit 0
fi

if (( resolvable == 0 && missing == 0 )); then
  printf "${GREEN}All secrets configured.${NC}\n"
  exit 0
fi

if (( resolvable > 0 )); then
  printf "${BOLD}Set %d resolvable secrets?${NC} [y/N] " "$resolvable"
  read -r confirm
  if [[ "$confirm" =~ ^[Yy] ]]; then
    for name in "${sorted_secrets[@]}"; do
      priority="${SECRET_PRIORITY[$name]}"
      [[ -n "$PRIORITY_FILTER" && "$priority" != "$PRIORITY_FILTER" ]] && continue
      is_configured "$name" && continue

      value="$(resolve_value "$name")"
      [[ -z "$value" ]] && value="$(try_resolve_from_tfvars "$name")"
      [[ -z "$value" ]] && continue

      if $DRY_RUN; then
        printf "${BLUE}[DRY-RUN]${NC} gh secret set %s -R %s\n" "$name" "$REPO"
      else
        printf "%s" "$value" | gh secret set "$name" -R "$REPO" --body -
        printf "${GREEN}  [SET]${NC} %s\n" "$name"
      fi
    done
  fi
fi

remaining_manual=0
for name in "${sorted_secrets[@]}"; do
  priority="${SECRET_PRIORITY[$name]}"
  [[ -n "$PRIORITY_FILTER" && "$priority" != "$PRIORITY_FILTER" ]] && continue
  is_configured "$name" && continue

  value="$(resolve_value "$name")"
  [[ -z "$value" ]] && value="$(try_resolve_from_tfvars "$name")"
  [[ -n "$value" ]] && continue

  (( ++remaining_manual ))
  if (( remaining_manual == 1 )); then
    printf "\n${BOLD}Manual secrets remaining:${NC}\n"
    printf "Set each with: gh secret set NAME -R %s\n\n" "$REPO"
  fi

  printf "  ${RED}%-35s${NC} %s  source: %s\n" "$name" "$priority" "${SECRET_SOURCE[$name]}"
done

printf "\nDone.\n"
