# Disaster Recovery Runbook

**Last Updated:** 2026-02-14

## Recovery Targets

| Metric | Target |
|--------|--------|
| RTO (Recovery Time Objective) | 4 hours |
| RPO (Recovery Point Objective) | 24 hours |

## Recovery Priority Order

1. **PVE Host** (100) — Hypervisor must be up first
2. **ELK** (105) — Logging pipeline
3. **cliproxy** (114) — Cloudflare Tunnel connector and CI/CD host
4. **Monitoring services** — alerting runtime managed by templates
5. **Remaining services** — active inventory entries

## Backup Strategy

| Component | Method | Location | Frequency |
|-----------|--------|----------|-----------|
| Terraform state | Local backend backups | Workspace `terraform/` directories and external backups | Before/after apply |
| Elasticsearch | Snapshot API | Local filesystem | Daily |
| Proxmox LXC/VM guests | vzdump | `pbs-backup` storage | Weekly |
| Cloudflare config | Terraform state backups | Local backend and external backups | Before/after apply |
| Docker volumes | Volume backup scripts | Local + NAS | Daily |

## Recovery Procedures

### PVE Host Down
```bash
# 1. Boot PVE from backup/reinstall
# 2. Restore network config
# 3. Start critical LXCs
pct start 105  # elk
pct start 114  # cliproxy
pct exec 114 -- systemctl start cloudflared-homelab
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

- [ ] Verify 1Password service-account authentication
- [ ] Verify Proxmox vzdump backups are current (< 7 days)
- [ ] Verify ES snapshots exist and are restorable
- [ ] Verify terraform plan shows no unexpected changes
- [ ] Verify Cloudflare tunnel reconnects after PVE restart
- [ ] Test service accessibility after recovery
- [ ] Document any gaps found during drill
