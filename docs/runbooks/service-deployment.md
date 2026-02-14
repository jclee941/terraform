# Service Deployment Runbook

**Last Updated:** 2026-02-14

## Prerequisites

- Terraform >= 1.5.0
- SSH access to PVE (`ssh root@192.168.50.100`)
- Vault access (for secret-dependent services)
- `gh` CLI authenticated (for GitHub operations)

## Standard Deployment Flow

### 1. Edit Configuration
```bash
# Edit the relevant service config
vim 100-pve/main.tf           # Infrastructure changes
vim NNN-service/templates/*.tftpl  # Service config templates
vim 100-pve/envs/prod/hosts.tf     # IP/port changes (SSoT)
```

### 2. Plan
```bash
make plan SVC=100-pve
# Review output carefully — check for destroy/replace actions
```

### 3. Apply
```bash
make apply SVC=100-pve
```

### 4. Verify
```bash
# Check service is running
ssh root@192.168.50.100 'pct status NNN'  # LXC
ssh root@192.168.50.100 'qm status NNN'   # VM

# Check service health
curl -s http://192.168.50.NNN:PORT/health

# Check logs
ssh root@192.168.50.100 'pct exec NNN -- journalctl -u service --since "5 minutes ago"'
```

## Rollback

### Quick Rollback (Terraform)
```bash
# Revert config changes
git checkout -- 100-pve/main.tf
# Re-plan and apply
make plan SVC=100-pve && make apply SVC=100-pve
```

### State-level Rollback
```bash
# View state history
terraform -chdir=100-pve state list
# If state is corrupted, restore from git
git log --oneline -- 100-pve/terraform.tfstate
git checkout <commit> -- 100-pve/terraform.tfstate
```

## Adding a New Service

1. Create directory: `mkdir NNN-service`
2. Add governance: `BUILD.bazel`, `OWNERS`
3. Add to `100-pve/main.tf` as a module call
4. Add host entry to `100-pve/envs/prod/hosts.tf`
5. Create templates in `NNN-service/templates/`
6. `terraform plan` → `terraform apply`
7. Verify: `bazel build //...`

## Post-Deploy Checklist

- [ ] Service responds on expected port
- [ ] Traefik routing works (if externally accessible)
- [ ] Logs flowing to ELK (check Grafana)
- [ ] Monitoring alerts not firing
- [ ] `terraform plan` shows no further changes
