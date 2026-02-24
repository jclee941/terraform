# scripts/ Utility Scripts

## OVERVIEW

Operational automation scripts for the `proxmox` infrastructure. Includes production health checks, PR automation, Terraform drift detection, and Filebeat deployment.

## STRUCTURE

```
scripts/
├── create-pr.sh                  # PR automation wrapper (gh cli + custom logic)
├── production_verification_v2.sh # Live health check suite (Prometheus, Grafana, N8N)
├── terraform-drift-check.sh      # DEPRECATED — use terraform-drift.yml workflow
├── setup-backups.sh              # Backup configuration (Restic/Borg)
├── setup-filebeat.sh             # Idempotent Filebeat install for LXC/VM hosts
├── sync-vault-secrets.sh         # Vault secret synchronization
├── setup-github-secrets.sh       # GitHub secrets provisioning
├── setup-local-env.sh            # Local dev environment setup
├── backup-tfstate.sh             # Terraform state backup
└── n8n-workflows/                # JSON workflow definitions (source of truth)
    ├── grafana-to-glitchtip.json # Grafana alert → GlitchTip bridge (n8n webhook)
    └── ...                       # Other exported workflows
```

## KEY SCRIPTS

### `production_verification_v2.sh`

**The "Test Suite" of the Monorepo.**

- **Purpose**: Verify live infrastructure health after deployments.
- **Checks**:
  - Service Reachability (HTTP 200/401)
  - Database Connections (PostgreSQL via GlitchTip)
  - Metrics ingestion (Prometheus targets up)
  - Workflow engine status (n8n healthz)
- **Usage**: `./scripts/production_verification_v2.sh`

### `create-pr.sh`

**Standard PR Workflow.**

- **Purpose**: Create GitHub PRs with standardized labels and descriptions.
- **Integrations**: Uses `gh` CLI, auto-detects changes to apply labels (`infrastructure`, `automation`, `documentation`).

### `terraform-drift-check.sh`

**DEPRECATED — Replaced by `terraform-drift.yml` GitHub Actions workflow.**

- **Status**: Script body replaced with deprecation notice. Drift detection is now event-driven via `.github/workflows/terraform-drift.yml`.
- **Migration**: 7-workspace matrix runs on push/PR events and `workflow_dispatch`.

### `setup-filebeat.sh`

**Filebeat Deployment.**

- **Purpose**: Idempotent Filebeat agent installation on LXC/VM hosts.
- **Called by**: `lxc-config` and `vm-config` modules via `setup_filebeat` provisioner.
- **Behavior**: Installs Filebeat, configures Docker autodiscovery, points output to Logstash on LXC 105.

### `sync-vault-secrets.sh`

**Vault Secret Sync.**

- **Purpose**: Synchronize secrets between 1Password and HashiCorp Vault.

## WHERE TO LOOK

| Task               | Script                          | Notes                                 |
| ------------------ | ------------------------------- | ------------------------------------- |
| Verify Prod Health | `production_verification_v2.sh` | Run after ANY deploy                  |
| Create PR          | `create-pr.sh`                  | Enforces naming conventions           |
| Check Drift        | `terraform-drift-check.sh`      | DEPRECATED — use `terraform-drift.yml` |
| Restore Backups    | `setup-backups.sh`              | Restic/Borg config                    |
| Deploy Filebeat    | `setup-filebeat.sh`             | Idempotent, called by TF provisioners |
| Sync Vault         | `sync-vault-secrets.sh`         | 1Password → Vault sync                |
| Manage n8n flows   | `n8n-workflows/AGENTS.md`       | Workflow JSON SSoT and sync rules     |
| GlitchTip bridge   | `n8n-workflows/grafana-to-glitchtip.json` | Grafana alert forwarding to GlitchTip |

## ANTI-PATTERNS

- **NO manual PR creation**: Use `create-pr.sh` to ensure correct labelling.
- **NO ignoring verification failures**: If `production_verification_v2.sh` fails, rollback or fix immediately.
- **NO running setup-filebeat.sh directly**: Use Terraform provisioner via CI/CD for consistent deployment.
- **NO running `make apply` locally**: `make apply` is disabled. All applies go through CI/CD (`terraform-apply.yml` or `{svc}-apply.yml`).
