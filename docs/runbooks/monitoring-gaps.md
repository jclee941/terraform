# Monitoring Gaps: Adding New Alert Rules

## Symptoms

- New service deployed without monitoring
- Known failure mode not covered by alerts
- False negatives — issues occurring without alerts firing

## Current Alerting Setup

| Component      | Location                                  | Rules                   |
| -------------- | ----------------------------------------- | ----------------------- |
| Alerting rules | Template/config pipeline rendered by `100-pve` | Current service health and log rules |
| Notifications  | alert-log-fallback                         | Routes to local alert logs |

Alert groups: `homelab-logs`, `mcp-alerts`, `infrastructure-health`

## Adding an Alert Rule

### 1. Define the Rule

Edit the alerting template/config source used by the `100-pve` config-renderer pipeline and add under the appropriate group:

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
# Apply via alerting runtime provisioning

# Verify rule appears
curl -s http://<alerting-runtime>/api/v1/provisioning/alert-rules \
  -H "Authorization: Bearer <api-key>" | jq '.[].title'
```

## Testing Alerts End-to-End

```bash
# 1. Trigger: Generate a test error in ELK
pct exec 105 -- curl -s -X POST "localhost:9200/logs-test-$(date +%Y.%m.%d)/_doc" \
  -H 'Content-Type: application/json' \
  -d '{"message": "test error", "level": "error", "service": "test"}'

# 2. Check: Verify alert fires in the alerting runtime
# 3. Verify: Check alert logs for notification

# 4. Verify: GitHub Issue created
gh issue list --repo qws941/terraform --label automated
```

## Prevention

- Every new service must have corresponding alerting rule
- Review `alerting.yaml` quarterly for stale/missing rules
- Document alert thresholds in service's AGENTS.md
- Test alert pipeline after any alerting or ELK config changes
- Verify PR automation workflows trigger correctly on new PRs
