# ELK Integration Template

Use this template when onboarding a new service into the ELK pipeline.

## Scope

- In scope: Filebeat tagging, Logstash parsing/routing, Elasticsearch index and ILM validation, Kibana discoverability.
- Out of scope: Manual edits in rendered configs under `100-pve/configs/**` and ad-hoc changes in Kibana Console.

## Inputs and Constraints

- Service name: `<service-name>`
- Host role: `<host-role>`
- Source host(s): `<host-list>`
- Log format: `json` | `plain` | `syslog`
- Retention tier: `critical-90d` | `default-30d` | `ephemeral-7d`
- Constraints:
  - Edit SSoT templates only: `105-elk/templates/*.tftpl`
  - Keep index naming `logs-{service}-YYYY.MM.dd`
  - Keep xpack security enabled
  - No public exposure of Elasticsearch 9200 outside LAN

## Decisions and Rules

### 1) Filebeat input and fields

- Ensure source input exists in `105-elk/templates/filebeat.yml.tftpl`:
  - `type: filestream`
  - `fields.service: <service-name>`
  - `fields.host_role: <host-role>`
- If service logs are Docker-based, keep autodiscovery enabled.

### 2) Logstash routing and normalization

- Update `105-elk/templates/logstash.conf.tftpl` only if service-specific parsing is required.
- Keep fallback service extraction path:
  - `[fields][service]`
  - Docker compose label fallback
  - default `unknown`
- Keep output index rule:

```conf
index => "logs-%{[service]}-%{+YYYY.MM.dd}"
```

### 3) ILM and template tier mapping

- For retention changes, edit `105-elk/terraform/main.tf`:
  - `logs-critical` -> `homelab-logs-critical-90d`
  - `logs-template` -> `homelab-logs-30d`
  - `logs-ephemeral` -> `homelab-logs-ephemeral-7d`
- Add `<service-name>` pattern to the correct index template set.

### 4) Traefik exposure rule (only if needed)

- If adding external endpoint behavior, update `102-traefik/templates/traefik-elk.yml.tftpl`.
- Keep ES route protected by LAN-only allowlist middleware.

## Verification

### A. Config and pipeline checks

```bash
# Logstash config syntax check
docker exec -it logstash bin/logstash -t -f /usr/share/logstash/pipeline/logstash.conf

# Elasticsearch health
curl -u elastic:$ELASTIC_PASSWORD localhost:9200/_cluster/health?pretty

# Logstash exporter metrics
curl -s localhost:9198/metrics | grep -E "logstash_(events|node)" | head -20
```

### B. Fresh ingestion check (required)

```bash
# Confirm fresh documents for this service in a narrow time window
curl -s -u elastic:$ELASTIC_PASSWORD \
  "localhost:9200/logs-<service-name>-*/_search" \
  -H 'Content-Type: application/json' \
  -d '{
    "size": 1,
    "sort": [{"@timestamp": "desc"}],
    "query": {
      "range": {
        "@timestamp": {
          "gte": "now-5m",
          "lte": "now"
        }
      }
    },
    "_source": ["@timestamp", "service", "level", "message", "host.name"]
  }'
```

### C. Index and ILM binding

```bash
# Verify index exists and lifecycle is attached
curl -s -u elastic:$ELASTIC_PASSWORD \
  "localhost:9200/logs-<service-name>-*/_settings" \
  | jq 'to_entries[] | {index: .key, ilm: .value.settings.index.lifecycle.name}'
```

## Rollback and Safety Notes

- Revert template and terraform changes in git, then redeploy via CI.
- If ingestion breaks, restore previous `logstash.conf.tftpl` and restart only Logstash.
- Do not delete indices unless migration verification confirms replacement index health.

## Completion Record

- Service: `<service-name>`
- Tier selected: `<tier>`
- Filebeat updated: `yes/no`
- Logstash updated: `yes/no`
- Terraform index template updated: `yes/no`
- Fresh event observed in last 5m: `yes/no`
- Verified by: `<name>`
- Date: `<YYYY-MM-DD>`
