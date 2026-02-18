# Disaster Recovery Runbook

**Last Updated:** 2026-02-14

## Recovery Targets

| Metric | Target |
|--------|--------|
| RTO (Recovery Time Objective) | 4 hours |
| RPO (Recovery Point Objective) | 24 hours |

## Recovery Priority Order

1. **PVE Host** (100) — Hypervisor must be up first
2. **Vault** (112:8200) — Infrastructure service (secrets now managed via 1Password)
3. **Traefik** (102) — Routing for all services
4. **ELK** (105) — Logging pipeline
5. **Grafana** (104) — Monitoring/alerting
6. **GlitchTip** (106) — Error tracking
7. **Runner** (101) — CI/CD
8. **Remaining services** — Supabase, Archon, MCPHub

## Backup Strategy

| Component | Method | Location | Frequency |
|-----------|--------|----------|-----------|
| Terraform state | Git (committed) | GitHub repo | Every change |
| Vault data | Raft snapshots | `/opt/vault/snapshots/` | Daily |
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

### Vault Recovery

> **Note:** Vault runs as infrastructure on VM 112 but is no longer the Terraform secret backend.
> Secrets are managed via 1Password (`OP_SERVICE_ACCOUNT_TOKEN`). This section covers Vault infrastructure recovery only.

```bash
ssh root@192.168.50.112
# 1. Check seal status
vault status
# 2. If sealed, unseal
vault operator unseal <key1>
vault operator unseal <key2>
vault operator unseal <key3>
# 3. If data lost, restore from snapshot
vault operator raft snapshot restore /opt/vault/snapshots/latest.snap
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

- [ ] Verify Vault unseal keys are accessible
- [ ] Verify Proxmox vzdump backups are current (< 7 days)
- [ ] Verify ES snapshots exist and are restorable
- [ ] Verify terraform plan shows no unexpected changes
- [ ] Verify Cloudflare tunnel reconnects after PVE restart
- [ ] Test service accessibility after recovery
- [ ] Document any gaps found during drill
