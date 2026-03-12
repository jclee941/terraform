# Disaster Recovery Runbook

**Last Updated:** 2026-02-14

## Recovery Targets

| Metric | Target |
|--------|--------|
| RTO (Recovery Time Objective) | 4 hours |
| RPO (Recovery Point Objective) | 24 hours |

## Recovery Priority Order

1. **PVE Host** (100) — Hypervisor must be up first
2. **1Password Connect** (112:8090) — Secret provider for all workspaces
3. **Traefik** (102) — Routing for all services
4. **ELK** (105) — Logging pipeline
5. **Grafana** (104) — Monitoring/alerting
6. **Runner** (101) — CI/CD
7. **Remaining services** — Supabase, Archon, MCPHub

## Backup Strategy

| Component | Method | Location | Frequency |
|-----------|--------|----------|-----------|
| Terraform state | Git (committed) | GitHub repo | Every change |
| Elasticsearch | Snapshot API | Local filesystem | Daily |
| Proxmox VMs/LXCs | vzdump | Synology NAS (215) | Weekly |
| Cloudflare config | Terraform state | Git | Every change |
| Docker volumes | Volume backup scripts | Local + NAS | Daily |

## Recovery Procedures

### PVE Host Down
```bash
# 1. Boot PVE from backup/reinstall
# 2. Restore network config
# 3. Start critical LXCs
pct start 102  # traefik
pct start 105  # elk
pct start 104  # grafana
```

### Terraform State Recovery
```bash
# State is in git — just re-init
cd 100-pve && terraform init
terraform plan  # verify state matches reality
```

### Elasticsearch Recovery
```bash
ssh root@192.168.50.100
pct exec 105 -- bash
# List snapshots
curl -s localhost:9200/_snapshot/backup/_all | jq '.snapshots[-1].snapshot'
# Restore latest
curl -X POST localhost:9200/_snapshot/backup/latest/_restore
```

### Supabase Recovery (LXC 107)
```bash
ssh root@192.168.50.100
pct start 107
pct exec 107 -- bash -c "cd /opt/supabase && docker compose up -d"
# Wait for all 13 services to become healthy
pct exec 107 -- bash -c "cd /opt/supabase && docker compose ps"
# Verify PostgREST
curl -s http://192.168.50.107:8000/rest/v1/ | head -5
```

### Archon Recovery (LXC 108)
```bash
ssh root@192.168.50.100
pct start 108
pct exec 108 -- bash -c "cd /opt/archon && docker compose up -d"
# Verify UI
curl -s -o /dev/null -w "%{http_code}" http://192.168.50.108:3737
# Archon depends on Supabase DB — ensure LXC 107 is up first
```

### Full Rebuild (Nuclear Option)
```bash
# 1. Fresh PVE install
# 2. Clone terraform repo
git clone git@github.com:qws941/terraform.git
cd terraform
# 3. Init + apply
cd 100-pve && terraform init && terraform apply
# 4. Deploy configs
# 5. Restore data from backups
```

## Recovery Drill Checklist

- [ ] Verify 1Password Connect Server health (LXC 112:8090)
- [ ] Verify Proxmox vzdump backups are current (< 7 days)
- [ ] Verify ES snapshots exist and are restorable
- [ ] Verify terraform plan shows no unexpected changes
- [ ] Verify Cloudflare tunnel reconnects after PVE restart
- [ ] Test service accessibility after recovery
- [ ] Document any gaps found during drill
