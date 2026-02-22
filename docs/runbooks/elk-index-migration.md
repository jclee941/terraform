# ELK Index Migration Runbook

Procedures for the index pattern migration from `logs-YYYY.MM.dd` to `logs-{service}-YYYY.MM.dd`.

## Pre-requisites

- SSH access to LXC 105 (`192.168.50.105`)
- `ELASTIC_PASSWORD` available (1Password `homelab/elk`)

## 1. Deploy Updated Configs

```bash
# From LXC 105
cd /opt/elk

# Copy updated logstash.conf (index pattern fix)
# Source: 105-elk/config/logstash.conf (committed to git)
# Key change: index => "logs-%{[service]}-%{+YYYY.MM.dd}"

# Restart Logstash only (no ES/Kibana restart needed)
docker compose restart logstash

# Verify Logstash is healthy
docker compose logs --tail=20 logstash | grep -i "pipeline"
curl -s localhost:9198/metrics | grep logstash_node_pipeline_events
```

## 2. Verify New Index Pattern

```bash
# Wait 2-3 minutes for new logs to arrive, then check
curl -s -u elastic:$ELASTIC_PASSWORD \
  'localhost:9200/_cat/indices/logs-*?v&s=index:desc&h=index,docs.count,store.size' \
  | head -20

# Expected: new indices like logs-grafana-2026.02.23, logs-system-2026.02.23
# Should NOT see new logs-2026.02.23 (date-only)
```

## 3. Delete Stale Date-Only Indices

Run only after step 2 confirms new pattern is active.

```bash
# List stale date-only indices (no service prefix)
curl -s -u elastic:$ELASTIC_PASSWORD \
  'localhost:9200/_cat/indices/logs-202*?v&h=index,docs.count,store.size'

# Delete all date-only indices (logs-YYYY.MM.dd pattern)
for idx in $(curl -s -u elastic:$ELASTIC_PASSWORD \
  'localhost:9200/_cat/indices/logs-202*?h=index'); do
  echo "Deleting ${idx}..."
  curl -s -X DELETE "localhost:9200/${idx}" -u elastic:$ELASTIC_PASSWORD
done
```

## 4. Delete Stale Service-Only Indices (No Date Suffix)

These are legacy indices from a previous config iteration.

```bash
# List service-only indices (no date suffix)
STALE_SERVICES="logs-analytics logs-auth logs-blackbox-exporter logs-ceph logs-db \
logs-docker logs-elasticsearch logs-grafana logs-kibana logs-kong logs-logstash \
logs-logstash-exporter logs-mcphub logs-mcp-playwright logs-mcp-proxmox logs-meta \
logs-n8n logs-opencode logs-prometheus logs-proxmox logs-realtime logs-redis \
logs-studio logs-supavisor logs-system logs-tempo logs-unknown logs-vault \
logs-vector logs-web logs-worker"

for idx in $STALE_SERVICES; do
  if curl -s -o /dev/null -w "%{http_code}" \
    "localhost:9200/${idx}" -u elastic:$ELASTIC_PASSWORD | grep -q 200; then
    echo "Deleting ${idx}..."
    curl -s -X DELETE "localhost:9200/${idx}" -u elastic:$ELASTIC_PASSWORD
  fi
done
```

## 5. Verify ILM Policy Application

```bash
# Check ILM policies exist
curl -s -u elastic:$ELASTIC_PASSWORD 'localhost:9200/_ilm/policy/homelab-logs-*' \
  | python3 -c "import sys,json; [print(f'{k}: delete_after={v[\"policy\"][\"phases\"][\"delete\"][\"min_age\"]}') for k,v in json.loads(sys.stdin.read()).items()]"

# Expected output:
# homelab-logs-30d: delete_after=30d
# homelab-logs-critical-90d: delete_after=90d
# homelab-logs-ephemeral-7d: delete_after=7d

# Verify a critical service index has the correct policy
curl -s -u elastic:$ELASTIC_PASSWORD \
  'localhost:9200/logs-grafana-*/_settings' \
  | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); [print(f'{k}: {v[\"settings\"][\"index\"].get(\"lifecycle\",{}).get(\"name\",\"NONE\")}') for k,v in d.items()]"
# Expected: homelab-logs-critical-90d (grafana is in critical tier)
```

## 6. Update Filebeat (All Hosts)

If filebeat config drift was also fixed:

```bash
# From each LXC host (101, 104, 105, 106, 107, 108, 112) and VM 220
# Copy updated filebeat.yml and restart
sudo systemctl restart filebeat
sudo systemctl status filebeat
```

## Rollback

If new index pattern causes issues:

```bash
# Revert logstash.conf output line to:
#   index => "logs-%{+YYYY.MM.dd}"
# Then restart:
docker compose -f /opt/elk/docker-compose.yml restart logstash
```

## Index Pattern Reference

| Template                | Pattern                                                   | ILM Policy                  | Retention |
| ----------------------- | --------------------------------------------------------- | --------------------------- | --------- |
| `logs-critical` (p300)  | `logs-archon-*,logs-elk-*,logs-supabase-*,logs-grafana-*` | `homelab-logs-critical-90d` | 90 days   |
| `logs-ephemeral` (p250) | `logs-unknown-*,logs-debug-*,logs-runner-*`               | `homelab-logs-ephemeral-7d` | 7 days    |
| `logs-template` (p200)  | `logs-*`                                                  | `homelab-logs-30d`          | 30 days   |
