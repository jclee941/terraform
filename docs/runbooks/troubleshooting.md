# Troubleshooting Runbook

**Last Updated:** 2026-02-14

## Service Down

### Check LXC Status
```bash
ssh root@192.168.50.100
pct list                              # All containers
pct status NNN                        # Specific container
pct start NNN                         # Start if stopped
```

### Check Docker Containers (inside LXC)
```bash
pct exec NNN -- docker ps -a          # List containers
pct exec NNN -- docker logs <name>    # View logs
pct exec NNN -- docker restart <name> # Restart
```

### Check VM Status
```bash
qm list                               # All VMs
qm status NNN                         # Specific VM
qm start NNN                          # Start if stopped
```

## Terraform Drift

```bash
# Check for drift
make drift-check
# Or manually
terraform -chdir=100-pve plan -detailed-exitcode
# Exit 0 = no changes, Exit 2 = drift detected

# Resolve drift
terraform -chdir=100-pve apply
```

## 1Password Issues

### Authentication Failure
```bash
# Check Connect Server connectivity (LXC 112, port 8090)
op whoami
# If failing, verify tokens
echo $OP_CONNECT_TOKEN | head -c 20
echo $OP_CONNECT_HOST
# Re-export if needed
export OP_CONNECT_TOKEN="<token>"
export OP_CONNECT_HOST="http://192.168.50.112:8090"
```

### Secret Not Found
```bash
# List items in homelab vault
op item list --vault homelab
# Read specific secret
op read "op://homelab/cloudflare/secrets/account_id"
# Check if item/field exists
op item get cloudflare --vault homelab --format json | jq '.fields'
```

## Network Issues

### Connectivity Chain
```bash
# 1. Local → PVE
ping 192.168.50.100
# 2. PVE → LXC
ssh root@192.168.50.100 'ping -c3 192.168.50.NNN'
# 3. LXC → External
pct exec NNN -- ping -c3 8.8.8.8
# 4. DNS resolution
pct exec NNN -- nslookup jclee.me
```

### Cloudflare Tunnel Down
```bash
# Check tunnel status on Synology
ssh root@192.168.50.215 'docker logs cloudflared --tail 20'
# Restart tunnel
ssh root@192.168.50.215 'docker restart cloudflared'
```

## Log Access

### Grafana (Dashboards)
- URL: http://192.168.50.104:3000
- External: https://grafana.jclee.me

### Elasticsearch (Raw Logs)
```bash
# Recent errors
curl -s 'http://192.168.50.105:9200/logs-*/_search' \
  -H 'Content-Type: application/json' \
  -d '{"query":{"bool":{"must":[{"match":{"level":"error"}},{"range":{"@timestamp":{"gte":"now-1h"}}}]}},"size":10}'
```

### Kibana
- URL: http://192.168.50.105:5601
- External: https://elk.jclee.me

## Prometheus Targets Down

```bash
# Check Prometheus targets
curl -s http://192.168.50.104:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health!="up")'
# Check node_exporter on specific host
curl -s http://192.168.50.NNN:9100/metrics | head
```

## Common Issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| LXC won't start | Disk full on PVE | `df -h` on PVE, clean up |
| Docker containers restarting | OOM | Increase memory in main.tf |
| TF plan shows unexpected changes | Manual edits | `terraform refresh`, revert manual changes |
| Logs not appearing in Grafana | Logstash down | Restart Logstash on 105 |
| External access broken | CF tunnel down | Restart cloudflared on 215 |
