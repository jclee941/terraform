#!/bin/bash
set -euo pipefail

ES_HOST="${ES_HOST:-http://localhost:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ELASTIC_PASSWORD:?ELASTIC_PASSWORD must be set}"
AUTH="-u ${ES_USER}:${ES_PASS}"

echo "=== Setting up ELK ILM Policies and Index Templates ==="

# --- ILM Policies (3-tier: default 30d, critical 90d, ephemeral 7d) ---

for policy in "homelab-logs-30d:30d" "homelab-logs-critical-90d:90d" "homelab-logs-ephemeral-7d:7d"; do
  name="${policy%%:*}"
  retention="${policy##*:}"
  echo "Creating ILM policy: ${name} (delete after ${retention})..."
  curl -s -X PUT "${ES_HOST}/_ilm/policy/${name}" ${AUTH} \
    -H "Content-Type: application/json" \
    -d "{
    \"policy\": {
      \"phases\": {
        \"hot\": { \"actions\": { \"set_priority\": { \"priority\": 100 } } },
        \"delete\": { \"min_age\": \"${retention}\", \"actions\": { \"delete\": {} } }
      }
    }
  }"
  echo ""
done

# --- Index Templates ---

echo "Creating index template: logs-template (priority 200, 30d)..."
curl -s -X PUT "${ES_HOST}/_index_template/logs-template" ${AUTH} \
  -H "Content-Type: application/json" \
  -d '{
  "index_patterns": ["logs-*"],
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0,
      "index.lifecycle.name": "homelab-logs-30d"
    }
  },
  "priority": 200
}'
echo ""

echo "Creating index template: logs-critical (priority 300, 90d)..."
curl -s -X PUT "${ES_HOST}/_index_template/logs-critical" ${AUTH} \
  -H "Content-Type: application/json" \
  -d '{
  "index_patterns": ["logs-archon-*", "logs-elk-*", "logs-supabase-*", "logs-grafana-*"],
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0,
      "index.lifecycle.name": "homelab-logs-critical-90d"
    }
  },
  "priority": 300
}'
echo ""

echo "Creating index template: logs-ephemeral (priority 250, 7d)..."
curl -s -X PUT "${ES_HOST}/_index_template/logs-ephemeral" ${AUTH} \
  -H "Content-Type: application/json" \
  -d '{
  "index_patterns": ["logs-unknown-*", "logs-debug-*", "logs-runner-*"],
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0,
      "index.lifecycle.name": "homelab-logs-ephemeral-7d"
    }
  },
  "priority": 250
}'
echo ""

# --- Verify ---

echo "=== Verification ==="
echo "ILM policies:"
curl -s "${ES_HOST}/_ilm/policy/homelab-logs-*" ${AUTH} | python3 -m json.tool 2>/dev/null || true
echo ""
echo "Index templates:"
curl -s "${ES_HOST}/_index_template/logs-*" ${AUTH} | python3 -c "import sys,json; d=json.load(sys.stdin); [print(f'  {t[\"name\"]}: patterns={t[\"index_patterns\"]}, priority={t.get(\"priority\",0)}') for t in d.get('index_templates',[])]" 2>/dev/null || true
echo ""
echo "=== ILM Setup Complete ==="
echo "Policies: homelab-logs-30d, homelab-logs-critical-90d, homelab-logs-ephemeral-7d"
echo "Templates: logs-template (p200), logs-critical (p300), logs-ephemeral (p250)"
echo "Index pattern: logs-{service}-YYYY.MM.dd"
