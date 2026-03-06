# AGENTS: scripts

## OVERVIEW

Operational automation scripts for the `proxmox` infrastructure. Includes production health checks, PR automation, Terraform drift detection, and Filebeat deployment.

## STRUCTURE

```
scripts/
├── create-pr.go                  # PR automation wrapper (gh cli + custom logic)
├── scaffold-workspace.go         # Scaffold new NNN-service workspace directories
├── production-verification.go    # Live health check suite (Prometheus, Grafana, N8N, ELK)
├── terraform-drift-check.sh      # DEPRECATED — use terraform-drift.yml workflow
├── setup-backups.sh              # Backup configuration (Restic/Borg)
├── setup-filebeat.sh             # Idempotent Filebeat install for LXC/VM hosts
├── sync-vault-secrets.go         # 1Password → GitHub secret sync (Go)
├── setup-github-secrets.go       # GitHub secrets provisioning (Go)
├── setup-local-env.sh            # Local dev environment setup
├── backup-tfstate.go              # Terraform state backup (Go)
└── n8n-workflows/                # JSON workflow definitions (source of truth)
    └── ...                       # Exported workflows
```

## CONVENTIONS

- `production-verification.go`: Checks HTTP reachability, PostgreSQL, Prometheus targets, Grafana dashboards, ELK stack health. Run after any deploy via `go run scripts/production-verification.go`.
- `terraform-drift-check.sh`: **DEPRECATED** — replaced by `terraform-drift.yml` workflow (7-workspace matrix).
- `setup-filebeat.sh`: Idempotent; called by TF provisioners (`lxc-config`/`vm-config`). Docker autodiscovery → Logstash on LXC 105.
- `scaffold-workspace.go`: Creates new numbered workspace directories with BUILD.bazel, OWNERS, README.md, AGENTS.md, main.tf, variables.tf, outputs.tf, versions.tf. Supports `--dry-run`.

## WHERE TO LOOK

| Task               | Script                                    | Notes                                            |
| ------------------ | ----------------------------------------- | ------------------------------------------------ |
| Verify Prod Health | `production-verification.go`              | Run after ANY deploy                             |
| Create PR          | `create-pr.go`                            | Enforces naming conventions                      |
| Check Drift        | `terraform-drift-check.sh`                | DEPRECATED — use `terraform-drift.yml`           |
| Restore Backups    | `setup-backups.sh`                        | Restic/Borg config                               |
| Deploy Filebeat    | `setup-filebeat.sh`                       | Idempotent, called by TF provisioners            |
| Sync Vault         | `sync-vault-secrets.go`                   | `go run scripts/sync-vault-secrets.go --audit`   |
| Manage n8n flows   | `n8n-workflows/AGENTS.md`                 | Workflow JSON SSoT and sync rules                |
| Scaffold Workspace | `scaffold-workspace.go`                   | `go run scripts/scaffold-workspace.go 113 redis` |

## ANTI-PATTERNS

- **NO manual PR creation**: Use `create-pr.go` to ensure correct labelling.
- **NO ignoring verification failures**: If `production-verification.go` fails, rollback or fix immediately.
- **NO running setup-filebeat.sh directly**: Use Terraform provisioner via CI/CD for consistent deployment.
- **NO running `make apply` locally**: `make apply` is disabled. All applies go through CI/CD (`terraform-apply.yml` or `{svc}-apply.yml`).
