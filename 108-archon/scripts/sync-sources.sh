#!/usr/bin/env bash
# sync-sources.sh — Sync documentation sources to Archon knowledge base.
# Reads sources.yml and crawls each URL via the Archon REST API.
#
# Usage:
#   bash 108-archon/scripts/sync-sources.sh [--dry-run] [--tag TAG] [--force]
#
# Requires: curl, python3 + pyyaml

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
ARCHON_API="${ARCHON_API:-http://192.168.50.108:8181/api}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES_FILE="${SCRIPT_DIR}/../sources.yml"
POLL_INTERVAL=5        # seconds between progress polls
POLL_TIMEOUT=600       # max seconds to wait per source (10 min)

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
DRY_RUN=false
FILTER_TAG=""
FORCE=false

usage() {
  cat <<EOF
${BOLD}sync-sources.sh${NC} — Sync documentation sources to Archon knowledge base

${BOLD}USAGE${NC}
  bash 108-archon/scripts/sync-sources.sh [OPTIONS]

${BOLD}OPTIONS${NC}
  --dry-run       Show what would be crawled without executing
  --tag TAG       Only process sources matching this tag
  --force         Re-crawl sources even if they already exist
  -h, --help      Show this help message

${BOLD}ENVIRONMENT${NC}
  ARCHON_API      Archon server base URL (default: http://192.168.50.108:8181/api)

${BOLD}EXAMPLES${NC}
  # Dry-run all sources
  bash 108-archon/scripts/sync-sources.sh --dry-run

  # Crawl only infra-tagged sources
  bash 108-archon/scripts/sync-sources.sh --tag infra

  # Force re-crawl everything
  bash 108-archon/scripts/sync-sources.sh --force
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)  DRY_RUN=true; shift ;;
    --tag)      FILTER_TAG="$2"; shift 2 ;;
    --force)    FORCE=true; shift ;;
    -h|--help)  usage; exit 0 ;;
    *)          echo -e "${RED}Unknown option: $1${NC}"; usage; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
for cmd in curl python3; do
  if ! command -v "$cmd" &>/dev/null; then
    echo -e "${RED}Error: '$cmd' is required but not found.${NC}"
    exit 1
  fi
done

python3 -c "import yaml" 2>/dev/null || {
  echo -e "${RED}Error: python3 'pyyaml' module is required. Install: pip3 install pyyaml${NC}"
  exit 1
}

if [[ ! -f "$SOURCES_FILE" ]]; then
  echo -e "${RED}Error: sources file not found: ${SOURCES_FILE}${NC}"
  exit 1
fi

# ---------------------------------------------------------------------------
# Parse sources.yml via python3
# ---------------------------------------------------------------------------
parse_sources() {
  python3 -c "
import yaml, json, sys

with open('${SOURCES_FILE}') as f:
    data = yaml.safe_load(f)

sources = data.get('sources', [])
filter_tag = '${FILTER_TAG}'

result = []
for s in sources:
    if s.get('enabled', True) is False:
        continue
    if filter_tag and filter_tag not in s.get('tags', []):
        continue
    result.append(s)

json.dump(result, sys.stdout)
"
}

# ---------------------------------------------------------------------------
# Get existing sources from Archon
# ---------------------------------------------------------------------------
get_existing_sources() {
  curl -s "${ARCHON_API}/knowledge-items/sources" 2>/dev/null || echo "[]"
}

# ---------------------------------------------------------------------------
# Check if a URL is already crawled
# ---------------------------------------------------------------------------
is_already_crawled() {
  local url="$1"
  local existing="$2"
  echo "$existing" | python3 -c "
import json, sys
data = json.load(sys.stdin)
url = '${url}'
# Check if URL exists in any source
if isinstance(data, list):
    for item in data:
        if isinstance(item, dict) and item.get('url', '') == url:
            print('true')
            sys.exit(0)
print('false')
" 2>/dev/null || echo "false"
}

# ---------------------------------------------------------------------------
# Start a crawl
# ---------------------------------------------------------------------------
start_crawl() {
  local url="$1"
  local knowledge_type="${2:-documentation}"
  local tags_json="$3"
  local max_depth="${4:-2}"
  local update_frequency="${5:-7}"

  local payload
  payload=$(python3 -c "
import json
data = {
    'url': '${url}',
    'knowledge_type': '${knowledge_type}',
    'tags': json.loads('${tags_json}'),
    'max_depth': ${max_depth},
    'update_frequency': ${update_frequency},
    'extract_code_examples': True
}
print(json.dumps(data))
")

  curl -s -X POST "${ARCHON_API}/knowledge-items/crawl" \
    -H "Content-Type: application/json" \
    -d "$payload"
}

# ---------------------------------------------------------------------------
# Poll crawl progress
# ---------------------------------------------------------------------------
poll_progress() {
  local progress_id="$1"
  local url="$2"
  local elapsed=0

  while [[ $elapsed -lt $POLL_TIMEOUT ]]; do
    local response
    response=$(curl -s "${ARCHON_API}/crawl-progress/${progress_id}" 2>/dev/null || echo '{}')

    local status
    status=$(echo "$response" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('status', 'unknown'))
" 2>/dev/null || echo "unknown")

    local progress
    progress=$(echo "$response" | python3 -c "
import json, sys
data = json.load(sys.stdin)
total = data.get('totalPages', 0)
processed = data.get('processedPages', 0)
if total > 0:
    print(f'{processed}/{total}')
else:
    print('...')
" 2>/dev/null || echo "...")

    case "$status" in
      completed|complete)
        echo -e "  ${GREEN}✓ Completed${NC} (pages: ${progress})"
        return 0
        ;;
      failed|error)
        echo -e "  ${RED}✗ Failed${NC}"
        echo -e "  ${RED}  Response: ${response}${NC}"
        return 1
        ;;
      *)
        printf "  ${CYAN}⟳ %s${NC} (pages: %s, %ds elapsed)\r" "$status" "$progress" "$elapsed"
        ;;
    esac

    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
  done

  echo -e "\n  ${YELLOW}⚠ Timeout after ${POLL_TIMEOUT}s — crawl may still be running${NC}"
  return 2
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  Archon Knowledge Base — Source Sync${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}API:${NC}     ${ARCHON_API}"
echo -e "${CYAN}Sources:${NC} ${SOURCES_FILE}"
[[ -n "$FILTER_TAG" ]] && echo -e "${CYAN}Filter:${NC}  tag=${FILTER_TAG}"
[[ "$DRY_RUN" == true ]] && echo -e "${YELLOW}Mode:    DRY RUN${NC}"
[[ "$FORCE" == true ]] && echo -e "${YELLOW}Mode:    FORCE (re-crawl existing)${NC}"
echo ""

# Verify Archon is reachable
if ! curl -s -o /dev/null -w "%{http_code}" "${ARCHON_API}/knowledge-items/sources" | grep -q "200"; then
  echo -e "${RED}Error: Archon API is not reachable at ${ARCHON_API}${NC}"
  exit 1
fi

# Parse sources
SOURCES_JSON=$(parse_sources)
SOURCE_COUNT=$(echo "$SOURCES_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")

if [[ "$SOURCE_COUNT" -eq 0 ]]; then
  echo -e "${YELLOW}No sources to process.${NC}"
  exit 0
fi

echo -e "${BOLD}Found ${SOURCE_COUNT} source(s) to process${NC}"
echo ""

# Get existing sources for dedup
EXISTING=$(get_existing_sources)

# Process each source
CRAWLED=0
SKIPPED=0
FAILED=0

echo "$SOURCES_JSON" | python3 -c "
import json, sys
sources = json.load(sys.stdin)
for i, s in enumerate(sources):
    tags = json.dumps(s.get('tags', []))
    print(f\"{i}|{s['url']}|{s.get('knowledge_type','documentation')}|{tags}|{s.get('max_depth',2)}|{s.get('update_frequency',7)}\")
" | while IFS='|' read -r idx url ktype tags max_depth update_freq; do
  echo -e "${BOLD}[$(( idx + 1 ))/${SOURCE_COUNT}] ${url}${NC}"
  echo -e "  type=${ktype}  tags=${tags}  depth=${max_depth}"

  # Check if already crawled
  already=$(is_already_crawled "$url" "$EXISTING")
  if [[ "$already" == "true" && "$FORCE" != true ]]; then
    echo -e "  ${YELLOW}⊘ Skipped (already exists, use --force to re-crawl)${NC}"
    SKIPPED=$((SKIPPED + 1))
    echo ""
    continue
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${CYAN}⊙ Would crawl${NC}"
    echo ""
    continue
  fi

  # Start crawl
  RESPONSE=$(start_crawl "$url" "$ktype" "$tags" "$max_depth" "$update_freq")

  # Extract progress ID
  PROGRESS_ID=$(echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
pid = data.get('progressId') or data.get('progress_id') or data.get('id', '')
print(pid)
" 2>/dev/null || echo "")

  if [[ -z "$PROGRESS_ID" || "$PROGRESS_ID" == "None" ]]; then
    echo -e "  ${RED}✗ Failed to start crawl${NC}"
    echo -e "  ${RED}  Response: ${RESPONSE}${NC}"
    FAILED=$((FAILED + 1))
    echo ""
    continue
  fi

  echo -e "  ${CYAN}Started crawl: ${PROGRESS_ID}${NC}"

  # Poll until done
  if poll_progress "$PROGRESS_ID" "$url"; then
    CRAWLED=$((CRAWLED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
  echo ""
done

# Summary (note: counters inside pipe subshell don't propagate,
# so we re-derive from log output or just print completion)
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  Sync complete${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "Run ${CYAN}bash 108-archon/scripts/sync-sources.sh --dry-run${NC} to preview."
echo -e "Verify via: ${CYAN}curl -s ${ARCHON_API}/knowledge-items/sources | python3 -m json.tool${NC}"
