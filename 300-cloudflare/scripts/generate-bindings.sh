#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY_FILE="${SCRIPT_DIR}/../inventory/secrets.yaml"
FORMAT="toml"
OUT_FILE=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [--format toml|jsonc] [--out FILE]

Options:
  --format FORMAT    Output format: toml (default) or jsonc
  --out FILE         Write output to file (default: stdout)
  -h, --help         Show this help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --format)
      FORMAT="${2:-}"
      shift
      ;;
    --out)
      OUT_FILE="${2:-}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if ! command -v yq >/dev/null 2>&1; then
  echo "yq is required" >&2
  exit 1
fi

if [ ! -f "$INVENTORY_FILE" ]; then
  echo "Inventory file not found: $INVENTORY_FILE" >&2
  exit 1
fi

store_id="$(yq -r '.store.id' "$INVENTORY_FILE")"
mapfile -t cf_secrets < <(yq -r '.secrets[] | select(.targets.cf_store == true) | .name' "$INVENTORY_FILE")

generate_toml() {
  local name
  for name in "${cf_secrets[@]}"; do
    cat <<EOF
[[secrets_store_secrets]]
binding = "${name}"
secret_name = "${name}"
store_id = "${store_id}"

EOF
  done
}

generate_jsonc() {
  local i name last
  echo "{"
  echo "  // Generated from inventory/secrets.yaml"
  echo "  \"secrets_store_secrets\": ["
  last=$((${#cf_secrets[@]} - 1))
  for i in "${!cf_secrets[@]}"; do
    name="${cf_secrets[$i]}"
    echo "    {"
    echo "      \"binding\": \"${name}\"," 
    echo "      \"secret_name\": \"${name}\"," 
    echo "      \"store_id\": \"${store_id}\""
    if [ "$i" -eq "$last" ]; then
      echo "    }"
    else
      echo "    },"
    fi
  done
  echo "  ]"
  echo "}"
}

case "$FORMAT" in
  toml)
    content="$(generate_toml)"
    ;;
  jsonc)
    content="$(generate_jsonc)"
    ;;
  *)
    echo "Invalid --format: ${FORMAT}" >&2
    exit 1
    ;;
esac

if [ -n "$OUT_FILE" ]; then
  printf "%s\n" "$content" > "$OUT_FILE"
else
  printf "%s\n" "$content"
fi
