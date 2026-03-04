#!/usr/bin/env bash
# Register ELK error alert watcher in Elasticsearch.
#
# Usage:
#   ./setup-watcher.sh <ES_HOST> <WEBHOOK_URL> <WEBHOOK_SECRET>
#
# Example:
#   ./setup-watcher.sh http://192.168.50.105:9200 \
#     https://issue-form.qws941.workers.dev/api/webhook/elk \
#     my-secret-token
#
# The watcher queries tier 1-2 errors every 5 minutes, aggregates by
# service and classification, and posts to the CF Worker webhook.
# Throttle: 1 hour per watch execution.

set -euo pipefail

ES_HOST="${1:?Usage: $0 <ES_HOST> <WEBHOOK_URL> <WEBHOOK_SECRET>}"
WEBHOOK_URL="${2:?Usage: $0 <ES_HOST> <WEBHOOK_URL> <WEBHOOK_SECRET>}"
WEBHOOK_SECRET="${3:?Usage: $0 <ES_HOST> <WEBHOOK_URL> <WEBHOOK_SECRET>}"

echo "Registering ELK error alert watcher..."
echo "  ES_HOST:     ${ES_HOST}"
echo "  WEBHOOK_URL: ${WEBHOOK_URL}"

curl -sf -X PUT "${ES_HOST}/_watcher/watch/elk-error-alerts" \
  -H 'Content-Type: application/json' \
  -d @- <<EOF
{
  "trigger": {
    "schedule": {
      "interval": "5m"
    }
  },
  "input": {
    "search": {
      "request": {
        "indices": ["logs-*"],
        "body": {
          "size": 0,
          "query": {
            "bool": {
              "filter": [
                { "range": { "@timestamp": { "gte": "now-5m" } } },
                { "terms": { "tier": [1, 2] } }
              ]
            }
          },
          "aggs": {
            "by_service": {
              "terms": { "field": "service.keyword", "size": 20 },
              "aggs": {
                "by_classification": {
                  "terms": { "field": "error_classification.keyword", "size": 10 },
                  "aggs": {
                    "severity": {
                      "terms": { "field": "error_severity.keyword", "size": 1 }
                    },
                    "tier": {
                      "min": { "field": "tier" }
                    },
                    "latest_message": {
                      "top_hits": {
                        "size": 1,
                        "_source": ["message", "@timestamp"],
                        "sort": [{ "@timestamp": "desc" }]
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  },
  "condition": {
    "compare": {
      "ctx.payload.hits.total": { "gt": 0 }
    }
  },
  "throttle_period": "1h",
  "actions": {
    "create_github_issue": {
      "throttle_period": "1h",
      "webhook": {
        "method": "POST",
        "url": "${WEBHOOK_URL}",
        "headers": {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${WEBHOOK_SECRET}"
        },
        "body": "{\"watch_id\": \"{{ctx.watch_id}}\", \"payload\": {{#toJson}}ctx.payload{{/toJson}}}"
      }
    }
  }
}
EOF

echo ""
echo "Watcher registered successfully."
echo ""
echo "Verify:"
echo "  curl -s '${ES_HOST}/_watcher/watch/elk-error-alerts' | jq '.status'"
echo ""
echo "Test (manual trigger):"
echo "  curl -s -X POST '${ES_HOST}/_watcher/watch/elk-error-alerts/_execute' | jq '.result'"
echo ""
echo "Delete:"
echo "  curl -s -X DELETE '${ES_HOST}/_watcher/watch/elk-error-alerts'"
