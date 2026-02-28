# AGENTS: scripts

## OVERVIEW

Operational automation scripts for the `proxmox` infrastructure. Includes production health checks, PR automation, Terraform drift detection, and Filebeat deployment.

## STRUCTURE

```
scripts/
├── create-pr.go                  # PR automation wrapper (gh cli + custom logic)
├── scaffold-workspace.go         # Scaffold new NNN-service workspace directories
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

## CONVENTIONS

- `production_verification_v2.sh`: Checks HTTP reachability, PostgreSQL (via GlitchTip), Prometheus targets, n8n healthz. Run after any deploy.
- `terraform-drift-check.sh`: **DEPRECATED** — replaced by `terraform-drift.yml` workflow (7-workspace matrix).
- `setup-filebeat.sh`: Idempotent; called by TF provisioners (`lxc-config`/`vm-config`). Docker autodiscovery → Logstash on LXC 105.
- `scaffold-workspace.go`: Creates new numbered workspace directories with BUILD.bazel, OWNERS, README.md, AGENTS.md, main.tf, variables.tf, outputs.tf, versions.tf. Supports `--dry-run`.

## WHERE TO LOOK

| Task               | Script                                    | Notes                                            |
| ------------------ | ----------------------------------------- | ------------------------------------------------ |
| Verify Prod Health | `production_verification_v2.sh`           | Run after ANY deploy                             |
| Create PR          | `create-pr.go`                            | Enforces naming conventions                      |
| Check Drift        | `terraform-drift-check.sh`                | DEPRECATED — use `terraform-drift.yml`           |
| Restore Backups    | `setup-backups.sh`                        | Restic/Borg config                               |
| Deploy Filebeat    | `setup-filebeat.sh`                       | Idempotent, called by TF provisioners            |
| Sync Vault         | `sync-vault-secrets.sh`                   | 1Password → Vault sync                           |
| Manage n8n flows   | `n8n-workflows/AGENTS.md`                 | Workflow JSON SSoT and sync rules                |
| GlitchTip bridge   | `n8n-workflows/grafana-to-glitchtip.json` | Grafana alert forwarding to GlitchTip            |
| Scaffold Workspace | `scaffold-workspace.go`                   | `go run scripts/scaffold-workspace.go 113 redis` |

## ANTI-PATTERNS

- **NO manual PR creation**: Use `create-pr.go` to ensure correct labelling.
- **NO ignoring verification failures**: If `production_verification_v2.sh` fails, rollback or fix immediately.
- **NO running setup-filebeat.sh directly**: Use Terraform provisioner via CI/CD for consistent deployment.
- **NO running `make apply` locally**: `make apply` is disabled. All applies go through CI/CD (`terraform-apply.yml` or `{svc}-apply.yml`).
