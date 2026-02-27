# Service Deployment Runbook
**Last Updated:** 2026-02-22

## Deployment Policy

**All deployments go through CI/CD. Manual `terraform apply` is disabled.**

- Push to `master` triggers automated apply workflows.
- Pull requests trigger plan workflows with PR comments.
- `make apply` is blocked — use CI/CD exclusively.

## Prerequisites

- Terraform >= 1.10.5
- SSH access to PVE (diagnostics only — not for deployment)
- 1Password Connect Server access (`OP_CONNECT_TOKEN` + `OP_CONNECT_HOST` for secret-dependent services)
- `gh` CLI authenticated (for GitHub operations)
## Standard Deployment Flow

### 1. Edit Configuration

```bash
# Edit the relevant service config
vim 100-pve/main.tf                    # Infrastructure changes
vim NNN-service/templates/*.tftpl      # Service config templates
vim 100-pve/envs/prod/hosts.tf         # IP/port changes (SSoT)
```

### 2. Create Pull Request

```bash
git checkout -b feat/your-change
git add -A && git commit -m "feat(svc): description"
git push -u origin feat/your-change
gh pr create --fill
```

CI automatically runs:
- **Terraform Validate** — catches config errors
- **Terraform Format Check** — enforces formatting
- **Terraform Plan** — plan output posted as PR comment

### 3. Review & Merge

- Review plan output in the PR comment
- Check for unexpected destroy/replace actions
- Merge to `master` → triggers automated apply

### 4. Automated Apply

Push to `master` triggers the corresponding apply workflow:
- `terraform-apply.yml` for 100-pve (core infrastructure)
- `{svc}-apply.yml` for service-specific workspaces (archon, cloudflare, elk, github, grafana, traefik)
- `worker-deploy.yml` for Cloudflare Workers

Each apply workflow includes:
- Pre-apply validation (`terraform validate`)
- `terraform apply -auto-approve`
- Post-apply verification (output validation)
- Automatic issue creation on failure

### 5. Verify (post-deploy)

```bash
# Run production verification
make verify

# Or check specific service
curl -s http://192.168.50.NNN:PORT/health
# Check Grafana dashboards for anomalies
# Check ELK for error spikes
```

## Rollback

### Quick Rollback (via CI/CD)

```bash
# Revert the change
git revert HEAD
git push origin master
# CI automatically applies the reverted state
```

### Emergency Rollback

If CI is broken, file an issue and use the self-hosted runner directly.
Never run `terraform apply` locally against production.

## Adding a New Service
1. Create directory: `mkdir NNN-service`
2. Add governance: `BUILD.bazel`, `OWNERS`
3. Add to `100-pve/main.tf` as a module call
4. Add host entry to `100-pve/envs/prod/hosts.tf`
5. Create templates in `NNN-service/templates/`
6. Create PR → CI runs plan → merge to master → CI applies
7. If service has its own Terraform workspace:
   - Create `{svc}-plan.yml` and `{svc}-apply.yml` using reusable `_terraform-plan.yml` / `_terraform-apply.yml`
   - Add to drift check matrix in `terraform-drift.yml`
8. Verify: `bazel build //...`

## CI Workflow Coverage

| Workspace | Plan Workflow | Apply Workflow | Trigger Paths |
|-----------|--------------|----------------|---------------|
| 100-pve | terraform-plan.yml | terraform-apply.yml | 100-pve/**, modules/** |
| Archon | archon-plan.yml | archon-apply.yml | 108-archon/** |
| Cloudflare | cloudflare-plan.yml | cloudflare-apply.yml | 300-cloudflare/** |
| ELK | elk-plan.yml | elk-apply.yml | 105-elk/** |
| Grafana | grafana-plan.yml | grafana-apply.yml | 104-grafana/** |
| Traefik | traefik-plan.yml | traefik-apply.yml | 102-traefik/** |
| CF Worker | — | worker-deploy.yml | 300-cloudflare/workers/** |

Services without dedicated workspaces (101-runner, 106-glitchtip, 107-supabase, 112-mcphub, 215-synology, 220-youtube) are managed through the 100-pve orchestrator.

## Post-Deploy Checklist

- [ ] CI apply workflow succeeded (green check in Actions)
- [ ] Service responds on expected port
- [ ] Traefik routing works (if externally accessible)
- [ ] Logs flowing to ELK (check Grafana)
- [ ] Monitoring alerts not firing
- [ ] `make plan SVC=xxx` shows no further drift
