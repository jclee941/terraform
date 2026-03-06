# Monitoring Gaps: Adding New Alert Rules

## Symptoms

- New service deployed without monitoring
- Known failure mode not covered by alerts
- False negatives — issues occurring without alerts firing

## Current Alerting Setup

| Component        | Location                                  | Rules                   |
| ---------------- | ----------------------------------------- | ----------------------- |
| Grafana Alerting | `104-grafana/terraform/alerting_rules.tf` | 14 rules, 3 groups      |
| Contact Points   | slack-alerts + alert-log-fallback          | Routes to Slack / logs  |

Alert groups: `homelab-logs`, `mcp-alerts`, `infrastructure-health`

## Adding a Grafana Alert Rule

### 1. Define the Rule

Edit `104-grafana/terraform/alerting_locals.tf` and add under the appropriate group:

```yaml
- uid: new-rule-uid
  title: "New Alert Name"
  condition: C
  data:
    - refId: A
      relativeTimeRange:
        from: 300 # 5 minutes
        to: 0
      datasourceUid: prometheus
      model:
        expr: 'up{job="your-job"} == 0'
        intervalMs: 1000
        maxDataPoints: 43200
    - refId: C
      relativeTimeRange:
        from: 300
        to: 0
      datasourceUid: __expr__
      model:
        type: threshold
        expression: A
        conditions:
          - evaluator:
              type: gt
              params: [0]
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Your alert summary"
```

### 2. Deploy

```bash
# Apply via Grafana provisioning
pct exec 104 -- docker compose -f /opt/grafana/docker-compose.yml restart grafana

# Verify rule appears
curl -s http://192.168.50.104:3000/api/v1/provisioning/alert-rules \
  -H "Authorization: Bearer <api-key>" | jq '.[].title'
```

## Testing Alerts End-to-End

```bash
# 1. Trigger: Generate a test error in ELK
pct exec 105 -- curl -s -X POST "localhost:9200/logs-test-$(date +%Y.%m.%d)/_doc" \
  -H 'Content-Type: application/json' \
  -d '{"message": "test error", "level": "error", "service": "test"}'

# 2. Check: Verify alert fires in Grafana
curl -s http://192.168.50.104:3000/api/v1/provisioning/alert-rules \
  # 3. Verify: Check Slack channel for alert notification

# 4. Verify: GitHub Issue created (if GlitchTip pipeline active)
gh issue list --repo qws941/terraform --label automated

# 4. Verify: GitHub Issue created
gh issue list --repo qws941/terraform --label automated
```

## Prevention

- Every new service must have corresponding alerting rule
- Review `alerting.yaml` quarterly for stale/missing rules
- Document alert thresholds in service's AGENTS.md
- Test alert pipeline after any Grafana/ELK config changes
- Verify PR automation workflows trigger correctly on new PRs
