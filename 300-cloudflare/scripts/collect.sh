#!/usr/bin/env bash
# collect.sh — Collect local secrets and generate secret-values.tfvars
# Scans .env and .tfvars files across projects, matches against secrets.yaml registry,
# and outputs a Terraform-compatible secret_values map.
#
# Usage:
#   ./scripts/collect.sh                  # Collect and write to terraform/secret-values.tfvars
#   ./scripts/collect.sh --dry-run        # Preview without writing
#   ./scripts/collect.sh --vault          # Also pull from Vault
#   ./scripts/collect.sh --format json    # Output as JSON
#   ./scripts/collect.sh --diff           # Show changes vs existing file

set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEV_DIR="$(cd "$ROOT_DIR/.." && pwd)"
INVENTORY="$ROOT_DIR/inventory/secrets.yaml"
DEFAULT_OUT="$ROOT_DIR/terraform/secret-values.tfvars"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Arguments ────────────────────────────────────────────────────────────────

DRY_RUN=false
USE_VAULT=false
FORMAT="tfvars"
OUT_FILE="$DEFAULT_OUT"
SHOW_DIFF=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)  DRY_RUN=true ;;
    --vault)    USE_VAULT=true ;;
    --format)   FORMAT="$2"; shift ;;
    --out)      OUT_FILE="$2"; shift ;;
    --diff)     SHOW_DIFF=true ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--vault] [--format tfvars|json] [--out FILE] [--diff]"
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

# ─── Dependency checks ───────────────────────────────────────────────────────

check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${RED}✗ Required: $1${NC}" >&2
    return 1
  fi
}

check_cmd yq || exit 1
$USE_VAULT && { check_cmd vault || exit 1; }
$USE_VAULT && { check_cmd jq || exit 1; }

# ─── Validate inventory ──────────────────────────────────────────────────────

if [[ ! -f "$INVENTORY" ]]; then
  echo -e "${RED}✗ Missing: $INVENTORY${NC}" >&2
  exit 1
fi

# ─── Build registry set from secrets.yaml ─────────────────────────────────────

declare -A REGISTRY
declare -A REGISTRY_VAULT_PATH

while IFS=$'\t' read -r name vault_path; do
  REGISTRY["$name"]=1
  [[ -n "$vault_path" && "$vault_path" != "null" ]] && REGISTRY_VAULT_PATH["$name"]="$vault_path"
done < <(yq -r '.secrets[] | [.name, .targets.vault // "null"] | @tsv' "$INVENTORY")

REGISTRY_COUNT=${#REGISTRY[@]}
echo -e "${BOLD}Secret Registry:${NC} $REGISTRY_COUNT secrets loaded from secrets.yaml"
echo ""

# ─── Source file map ──────────────────────────────────────────────────────────
# label:path pairs — label is for display, path is the .env/.tfvars file

declare -A ENV_FILES=(
  ["money"]="$DEV_DIR/money/.env"
  ["resume"]="$DEV_DIR/resume/.env"
  ["safework2"]="$DEV_DIR/safework2/.env"
  ["safework"]="$DEV_DIR/safework/workers/.env"
  ["slack"]="$DEV_DIR/slack/.env"
  ["slack-bot"]="$DEV_DIR/slack/typescript/slack-bot/.env"
  ["proxmox-tf"]="$DEV_DIR/proxmox/terraform/terraform.tfvars"
  ["splunk-tf"]="$DEV_DIR/splunk/terraform/terraform.tfvars"
  ["splunk"]="$DEV_DIR/splunk/.env"
  ["blacklist"]="$DEV_DIR/blacklist/.env"
  ["blacklist-agent"]="$DEV_DIR/blacklist/agent/.env"
  ["elk"]="$DEV_DIR/proxmox/105-elk/.env"
)

# ─── Collectors ───────────────────────────────────────────────────────────────

declare -A COLLECTED        # name → value
declare -A COLLECTED_SOURCE # name → source label

# Parse KEY=VALUE from .env file (handles quotes, comments, blank lines)
# Uses fd 3 to avoid stdin conflicts
parse_env_file() {
  local file="$1" label="$2"
  local count=0

  while IFS= read -r -u3 line; do
    # Skip blank lines, comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Strip inline comments (but not inside quotes)
    local key value
    key="${line%%=*}"
    value="${line#*=}"

    # Skip lines without =
    [[ "$key" == "$line" ]] && continue

    # Trim whitespace from key
    key="$(echo "$key" | xargs)"

    # Skip non-variable lines (must start with letter/underscore)
    [[ ! "$key" =~ ^[A-Za-z_] ]] && continue

    # Strip surrounding quotes from value
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"

    # Trim leading/trailing whitespace
    value="$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    # Skip empty values
    [[ -z "$value" ]] && continue

    # Store (first source wins — don't overwrite)
    if [[ -z "${COLLECTED[$key]+x}" ]]; then
      COLLECTED["$key"]="$value"
      COLLECTED_SOURCE["$key"]="$label"
      (( ++count ))
    fi
  done 3< "$file"

  echo -e "  ${GREEN}✓${NC} ${label}: ${count} vars"
}

# Parse terraform.tfvars (HCL key = "value" format)
parse_tfvars_file() {
  local file="$1" label="$2"
  local count=0

  while IFS= read -r -u3 line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Match: key = "value" or key = value
    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*) ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"

      # Strip quotes
      value="${value#\"}"
      value="${value%\"}"
      value="${value#\'}"
      value="${value%\'}"
      value="$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

      [[ -z "$value" ]] && continue

      if [[ -z "${COLLECTED[$key]+x}" ]]; then
        COLLECTED["$key"]="$value"
        COLLECTED_SOURCE["$key"]="$label"
        (( ++count ))
      fi
    fi
  done 3< "$file"

  echo -e "  ${GREEN}✓${NC} ${label}: ${count} vars"
}

# ─── Phase 1: Scan local files ───────────────────────────────────────────────

echo -e "${BOLD}Phase 1: Scanning local files${NC}"

found_files=0
for label in "${!ENV_FILES[@]}"; do
  file="${ENV_FILES[$label]}"
  [[ ! -f "$file" ]] && continue

  (( ++found_files ))

  if [[ "$file" == *.tfvars ]]; then
    parse_tfvars_file "$file" "$label"
  else
    parse_env_file "$file" "$label"
  fi
done

echo -e "  Scanned ${CYAN}${found_files}${NC} files, collected ${CYAN}${#COLLECTED[@]}${NC} unique vars"
echo ""

# ─── Phase 2: Vault collection (optional) ────────────────────────────────────

if $USE_VAULT; then
  echo -e "${BOLD}Phase 2: Pulling from Vault${NC}"

  VAULT_ADDR="${VAULT_ADDR:-$(yq -r '.vault.address' "$INVENTORY")}"
  VAULT_MOUNT="$(yq -r '.vault.mount' "$INVENTORY")"
  export VAULT_ADDR

  if ! vault token lookup &>/dev/null; then
    echo -e "  ${RED}✗ Vault authentication failed${NC}"
    echo -e "  Set VAULT_TOKEN or run: vault login"
  else
    # Get unique vault paths from registry
    declare -A VAULT_PATHS
    for name in "${!REGISTRY_VAULT_PATH[@]}"; do
      VAULT_PATHS["${REGISTRY_VAULT_PATH[$name]}"]=1
    done

    vault_count=0
    for vpath in "${!VAULT_PATHS[@]}"; do
      full_path="${VAULT_MOUNT}/data/${vpath}"
      if json=$(vault kv get -format=json "${VAULT_MOUNT}/${vpath}" 2>/dev/null); then
        # Extract all key-value pairs from the secret
        while IFS=$'\t' read -r -u3 k v; do
          [[ -z "$k" ]] && continue
          # Vault values don't overwrite local values
          if [[ -z "${COLLECTED[$k]+x}" ]]; then
            COLLECTED["$k"]="$v"
            COLLECTED_SOURCE["$k"]="vault:${vpath}"
            (( ++vault_count ))
          fi
        done 3< <(echo "$json" | jq -r '.data.data | to_entries[] | [.key, .value] | @tsv')
        echo -e "  ${GREEN}✓${NC} ${vpath}"
      else
        echo -e "  ${YELLOW}⚠${NC} ${vpath} (not found or no access)"
      fi
    done

    echo -e "  Collected ${CYAN}${vault_count}${NC} additional vars from Vault"
  fi
  echo ""
else
  echo -e "${BOLD}Phase 2: Vault${NC} (skipped — use --vault to enable)"
  echo ""
fi

# ─── Phase 3: Match against registry ─────────────────────────────────────────

echo -e "${BOLD}Phase 3: Matching against registry${NC}"

declare -A MATCHED     # registry name → value
declare -A UNMATCHED   # collected but not in registry

for key in "${!COLLECTED[@]}"; do
  if [[ -n "${REGISTRY[$key]+x}" ]]; then
    MATCHED["$key"]="${COLLECTED[$key]}"
  else
    UNMATCHED["$key"]=1
  fi
done

# Find missing (in registry but not collected)
declare -A MISSING
for name in "${!REGISTRY[@]}"; do
  if [[ -z "${MATCHED[$name]+x}" ]]; then
    MISSING["$name"]=1
  fi
done

echo -e "  ${GREEN}✓ Matched:${NC}  ${#MATCHED[@]}/${REGISTRY_COUNT}"
echo -e "  ${RED}✗ Missing:${NC}  ${#MISSING[@]}/${REGISTRY_COUNT}"
echo -e "  ${YELLOW}⚠ Unregistered:${NC} ${#UNMATCHED[@]} (not in secrets.yaml)"
echo ""

# ─── Phase 4: Generate output ────────────────────────────────────────────────

mask_value() {
  local v="$1"
  local len=${#v}
  if (( len <= 4 )); then
    echo "****"
  elif (( len <= 8 )); then
    echo "${v:0:2}****"
  else
    echo "${v:0:4}…${v: -2}"
  fi
}

generate_tfvars() {
  echo '# Auto-generated by collect.sh'
  echo "# $(date -Iseconds)"
  echo '# DO NOT COMMIT — contains secret values'
  echo ''
  echo 'secret_values = {'

  # Sort keys for deterministic output
  local sorted_keys
  sorted_keys=$(printf '%s\n' "${!MATCHED[@]}" | sort)

  while IFS= read -r -u3 key; do
    [[ -z "$key" ]] && continue
    local val="${MATCHED[$key]}"
    # Escape backslashes and quotes for HCL
    val="${val//\\/\\\\}"
    val="${val//\"/\\\"}"
    echo "  ${key} = \"${val}\""
  done 3<<< "$sorted_keys"

  echo '}'
}

generate_json() {
  echo '{'
  local first=true
  local sorted_keys
  sorted_keys=$(printf '%s\n' "${!MATCHED[@]}" | sort)

  while IFS= read -r -u3 key; do
    [[ -z "$key" ]] && continue
    local val="${MATCHED[$key]}"
    val="${val//\\/\\\\}"
    val="${val//\"/\\\"}"
    $first || echo ','
    printf '  "%s": "%s"' "$key" "$val"
    first=false
  done 3<<< "$sorted_keys"

  echo ''
  echo '}'
}

if $DRY_RUN; then
  echo -e "${BOLD}Phase 4: Preview (dry-run)${NC}"
  echo ""

  echo -e "${CYAN}Matched secrets:${NC}"
  for key in $(printf '%s\n' "${!MATCHED[@]}" | sort); do
    src="${COLLECTED_SOURCE[$key]:-unknown}"
    echo -e "  ${GREEN}✓${NC} ${key} = $(mask_value "${MATCHED[$key]}") ${BLUE}← ${src}${NC}"
  done

  if (( ${#MISSING[@]} > 0 )); then
    echo ""
    echo -e "${CYAN}Missing secrets (not found locally):${NC}"
    for key in $(printf '%s\n' "${!MISSING[@]}" | sort); do
      echo -e "  ${RED}✗${NC} ${key}"
    done
  fi

  if (( ${#UNMATCHED[@]} > 0 )); then
    echo ""
    echo -e "${CYAN}Unregistered vars (consider adding to secrets.yaml):${NC}"
    for key in $(printf '%s\n' "${!UNMATCHED[@]}" | sort | head -20); do
      echo -e "  ${YELLOW}⚠${NC} ${key} ${BLUE}← ${COLLECTED_SOURCE[$key]:-unknown}${NC}"
    done
    unreg_count=${#UNMATCHED[@]}
    (( unreg_count > 20 )) && echo -e "  … and $((unreg_count - 20)) more"
  fi

  echo ""
  echo -e "${BOLD}Would write ${#MATCHED[@]} secrets to:${NC} $OUT_FILE"

elif $SHOW_DIFF; then
  echo -e "${BOLD}Phase 4: Diff${NC}"
  if [[ -f "$OUT_FILE" ]]; then
    diff <(cat "$OUT_FILE") <(generate_tfvars) || true
  else
    echo -e "  ${YELLOW}No existing file to diff against${NC}"
    generate_tfvars
  fi

else
  echo -e "${BOLD}Phase 4: Writing output${NC}"

  case "$FORMAT" in
    tfvars)
      generate_tfvars > "$OUT_FILE"
      ;;
    json)
      generate_json > "$OUT_FILE"
      ;;
    *)
      echo -e "${RED}Unknown format: $FORMAT${NC}" >&2
      exit 1
      ;;
  esac

  echo -e "  ${GREEN}✓${NC} Written ${#MATCHED[@]} secrets to ${BOLD}${OUT_FILE}${NC}"
  echo -e "  ${YELLOW}⚠ DO NOT COMMIT this file${NC}"
fi

echo ""
echo -e "${BOLD}Summary:${NC} ${GREEN}${#MATCHED[@]}${NC} collected, ${RED}${#MISSING[@]}${NC} missing, ${YELLOW}${#UNMATCHED[@]}${NC} unregistered"
