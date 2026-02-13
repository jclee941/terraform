#!/bin/bash
set -euo pipefail

ES_HOST="http://localhost:9200"

echo "=== Setting up ELK ILM and Index Templates ==="

echo "Creating ILM policy..."
curl -X PUT "${ES_HOST}/_ilm/policy/logs-policy" \
  -H "Content-Type: application/json" \
  -d @/opt/elk/config/ilm-policy.json

echo ""
echo "Creating index template..."
curl -X PUT "${ES_HOST}/_index_template/logs-template" \
  -H "Content-Type: application/json" \
  -d '{
  "index_patterns": ["logs-*"],
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0,
      "index.lifecycle.name": "logs-policy",
      "index.lifecycle.rollover_alias": "logs"
    },
    "mappings": {
      "properties": {
        "@timestamp": { "type": "date" },
        "message": { "type": "text" },
        "host": { "type": "keyword" },
        "service": { "type": "keyword" },
        "level": { "type": "keyword" }
      }
    }
  },
  "priority": 100
}'

echo ""
echo "Creating initial index with alias..."
curl -X PUT "${ES_HOST}/logs-000001" \
  -H "Content-Type: application/json" \
  -d '{
  "aliases": {
    "logs": {
      "is_write_index": true
    }
  }
}'

echo ""
echo "=== ILM Setup Complete ==="
echo "Policy: logs-policy (hot: 1d/10GB, warm: 7d, delete: 30d)"
