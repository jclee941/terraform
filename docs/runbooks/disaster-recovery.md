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
5. **Monitoring services** — alerting runtime managed by templates
6. **Runner** (101) — CI/CD
7. **Remaining services** — MCPHub and other active inventory entries

## Backup Strategy

| Component | Method | Location | Frequency |
|-----------|--------|----------|-----------|
| Terraform state | Local backend backups | Workspace `terraform/` directories and external backups | Before/after apply |
| Elasticsearch | Snapshot API | Local filesystem | Daily |
| Proxmox VMs/LXCs | vzdump | Synology NAS (215) | Weekly |
| Cloudflare config | Terraform state backups | Local backend and external backups | Before/after apply |
| Docker volumes | Volume backup scripts | Local + NAS | Daily |

## Recovery Procedures

### PVE Host Down
```bash
# 1. Boot PVE from backup/reinstall
# 2. Restore network config
# 3. Start critical LXCs
pct start 102  # traefik
pct start 105  # elk
# Start monitoring runtime if present in current inventory
```

### Terraform State Recovery
```bash
# Restore the latest known-good local backend state backup first, then re-init
cd 100-pve/terraform && terraform init
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

### Full Rebuild (Nuclear Option)
```bash
# 1. Fresh PVE install
# 2. Clone terraform repo
git clone git@github.com:qws941/terraform.git
cd terraform
# 3. Validate locally, then trigger CI/CD apply
terraform -chdir=100-pve/terraform init -backend=false
terraform -chdir=100-pve/terraform validate
# 4. Deploy configs through GitHub Actions apply workflow
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
