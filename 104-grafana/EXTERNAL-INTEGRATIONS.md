# External Service Integration Guide

How to send alerts from external services (GitHub Actions, etc.) to your Grafana alerting system.

---

## Quick Links

| Service | Method | Difficulty | Setup Time |
|---------|--------|-----------|-----------|
| **Slack** (Direct) | POST to webhook | ⭐ Easy | 5 min |
| **GitHub Actions** | Slack webhook | ⭐ Easy | 10 min |
| **Custom Services** | Slack or Grafana webhook | ⭐⭐ Medium | 15 min |

---

## Method 1: Direct Slack Webhook (Simplest)

**Use this for**: GitHub Actions, GitLab CI, custom scripts, third-party services

### Setup

```bash
# Slack webhook URL (already configured in homelab)
SLACK_WEBHOOK="https://hooks.slack.com/services/TXXXXXXXX/BXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXX"

# Send alert from any service
curl -X POST "$SLACK_WEBHOOK" \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "🚨 Build Failed",
    "blocks": [
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "*GitHub Actions*\n*Build #123 Failed*\nRepository: qws941/terraform\nBranch: main\nAuthor: @jclee"
        }
      },
      {
        "type": "section",
        "fields": [
          {
            "type": "mrkdwn",
            "text": "*Severity*\nCritical"
          },
          {
            "type": "mrkdwn",
            "text": "*Status*\nFailing"
          }
        ]
      },
      {
        "type": "actions",
        "elements": [
          {
            "type": "button",
            "text": {
              "type": "plain_text",
              "text": "View Run"
            },
            "url": "https://github.com/qws941/terraform/actions/runs/123"
          }
        ]
      }
    ]
  }'
```

### GitHub Actions Example

Add to `.github/workflows/ci.yml`:

```yaml
name: Build & Test

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: npm test

      # On failure, send to Grafana/Slack
      - name: Notify Failure
        if: failure()
        run: |
          curl -X POST "${{ secrets.SLACK_WEBHOOK }}" \
            -H 'Content-Type: application/json' \
            -d '{
              "text": "❌ Build Failed",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*GitHub Actions*\n*${{ github.repository }}*\nCommit: ${{ github.sha }}\nBranch: ${{ github.ref }}"
                  }
                },
                {
                  "type": "actions",
                  "elements": [
                    {
                      "type": "button",
                      "text": {"type": "plain_text", "text": "View Run"},
                      "url": "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
                    }
                  ]
                }
              ]
            }'
```

Store webhook as GitHub secret:
```bash
gh secret set SLACK_WEBHOOK --body "https://hooks.slack.com/services/TXXXXXXXX/BXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXX"
```

---

## Method 3: Grafana Webhook Contact Point (Advanced)

For services that need to integrate with Grafana's alert routing.

### Step 1: Add webhook contact point to alerting.yaml

```yaml
contactPoints:
  - orgId: 1
    name: external-webhook
    receivers:
      - uid: external-webhook-receiver
        type: webhook
        settings:
          url: "http://192.168.50.104:3000/api/v1/rules/test"
          httpMethod: "POST"
```

### Step 2: Send payload in Prometheus format

```bash
curl -X POST "http://192.168.50.104:3000/api/v1/rules/test" \
  -H 'Content-Type: application/json' \
  -d '{
    "groupLabels": {
      "alertname": "ExternalServiceAlert",
      "service": "github"
    },
    "commonLabels": {
      "severity": "warning",
      "environment": "production"
    },
    "commonAnnotations": {
      "summary": "Build deployment failed",
      "description": "Deployment to production failed in GitHub Actions"
    },
    "alerts": [
      {
        "status": "firing",
        "labels": {
          "alertname": "ExternalServiceAlert",
          "severity": "warning",
          "service": "github",
          "job": "build-deploy"
        },
        "annotations": {
          "summary": "Build deployment failed",
          "description": "Deployment to production failed"
        },
        "startsAt": "2026-02-01T17:56:50+09:00",
        "endsAt": "0001-01-01T00:00:00Z"
      }
    ]
  }'
```

---

## Method 4: Custom Python Script

Send alerts from custom monitoring scripts:

```python
#!/usr/bin/env python3
import requests
import json
from datetime import datetime

SLACK_WEBHOOK = "https://hooks.slack.com/services/TXXXXXXXX/BXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXX"

def send_alert(service, severity, summary, description, metadata=None):
    """Send alert to Slack via Grafana"""

    emoji_map = {
        "critical": "🚨",
        "warning": "⚠️",
        "info": "ℹ️",
    }

    emoji = emoji_map.get(severity, "📢")

    blocks = [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"{emoji} **{severity.upper()}** Alert\n*{service}*\n{summary}"
            }
        }
    ]

    if description:
        blocks.append({
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"_{description}_"
            }
        })

    if metadata:
        fields = []
        for key, value in metadata.items():
            fields.append({
                "type": "mrkdwn",
                "text": f"*{key}*\n{value}"
            })
        blocks.append({
            "type": "section",
            "fields": fields
        })

    payload = {
        "text": f"{emoji} {service} - {severity}",
        "blocks": blocks
    }

    response = requests.post(SLACK_WEBHOOK, json=payload)
    response.raise_for_status()
    print(f"Alert sent: {summary}")

# Example usage
if __name__ == "__main__":
    send_alert(
        service="Custom Monitor",
        severity="warning",
        summary="Disk usage critical",
        description="Root filesystem at 92% capacity",
        metadata={
            "Host": "pve",
            "Disk": "/dev/sda1",
            "Usage": "92%"
        }
    )
```

---

## Method 6: Docker/Compose Health Checks

Send alerts when Docker containers fail:

```yaml
version: '3.8'

services:
  my-app:
    image: myapp:latest
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

    # On unhealthy, send alert
    labels:
      - "alert.slack.webhook=${SLACK_WEBHOOK}"
```

Or use `docker events` to watch for container failures:

```bash
#!/bin/bash

docker events --filter 'type=container' --filter 'status=die' --format '{{json .}}' | \
while read -r event; do
  container=$(echo "$event" | jq -r '.Actor.Attributes.name')
  image=$(echo "$event" | jq -r '.Actor.Attributes.image')

  curl -X POST "$SLACK_WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{
      \"text\": \"🔴 Container Died\",
      \"blocks\": [{
        \"type\": \"section\",
        \"text\": {
          \"type\": \"mrkdwn\",
          \"text\": \"*Docker Container Failed*\n*Container*: $container\n*Image*: $image\"
        }
      }]
    }"
done
```

---

## Testing Your Integration

### Test webhook with curl

```bash
WEBHOOK="https://hooks.slack.com/services/TXXXXXXXX/BXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXX"

curl -X POST "$WEBHOOK" \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "✅ Test Alert",
    "blocks": [
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "*Integration Test Successful*\nWebhook is working!"
        }
      }
    ]
  }'
```

### Test Grafana webhook

```bash
curl -X POST "http://192.168.50.104:3000/api/v1/rules/test" \
  -H 'Content-Type: application/json' \
  -d @test-alert.json
```

Where `test-alert.json` is the Prometheus format payload above.

---

## Slack Message Formatting

### Status badges

- 🚨 Critical (immediate action needed)
- ⚠️ Warning (attention needed)
- ℹ️ Info (informational)
- ✅ Resolved (alert cleared)
- ❌ Failed (failed action/deployment)

### Useful Slack blocks

```json
{
  "type": "divider"
}
```

```json
{
  "type": "context",
  "elements": [
    {
      "type": "mrkdwn",
      "text": "Last updated: <!date^1234567890^{date} at {time}|Feb 1 at 5:56 PM>"
    }
  ]
}
```

```json
{
  "type": "section",
  "text": {
    "type": "mrkdwn",
    "text": ":spiral_calendar_pad: *When*\nMay 6, 2019 @ 09:53 AM"
  }
}
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Webhook returns 403 | Slack webhook URL may be expired or invalid |
| Alert not appearing in Slack | Check channel name in webhook URL matches configured Slack channel |
| Grafana webhook not routing | Ensure severity/label matchers are correct in routing policy |
| Too many alerts | Adjust `group_wait` and `group_interval` in routing policy |
| Slack rate limiting | Reduce alert frequency or consolidate into digest channel |

---

## Security Best Practices

1. ✅ Store webhook URLs as environment variables (not in code)
2. ✅ Rotate webhook URLs periodically
3. ✅ Use separate webhooks for different services if possible
4. ✅ Restrict Slack channel access (webhook has channel-level permissions only)
5. ⚠️ Do not log webhook URLs in error messages
6. ⚠️ Do not commit webhook URLs to git repositories

---

## Next Steps

1. **Choose integration method** based on your needs (Slack direct is usually easiest)
2. **Test with curl** before integrating into automation
3. **Monitor Slack channel** for alert delivery
4. **Tune alert thresholds** to avoid alert fatigue
5. **Document alert runbooks** for each alert type
6. **Set up escalation** (e.g., PagerDuty for critical alerts)
