# AGENTS: scripts

## OVERVIEW

Operational automation scripts for the `proxmox` infrastructure. Includes production health checks, PR automation, state backup, workflow/docs audits, and Filebeat deployment.

## STRUCTURE

```
scripts/
├── create-pr.go                  # PR automation wrapper (gh cli + custom logic)
├── scaffold-workspace.go         # Scaffold new NNN-service workspace directories
├── production-verification.go    # Live health check suite for deployed services
├── setup-filebeat.go             # Local filebeat setup tool (Go, root-only)
├── install-filebeat.sh           # Remote execution payload for TF provisioners (SCP'd to hosts)
├── sync-vault-secrets.go         # 1Password → GitHub secret sync (Go)
├── setup-github-secrets.go       # GitHub secrets provisioning (Go)
├── setup-local-env.go            # Local dev environment setup (Go)
├── backup-tfstate.go             # Encrypted backup of local-backend Terraform state (Go)
├── audit-workflows.go            # .github/workflow-registry.yml drift audit (Go)
└── validate-docs/                # Markdown link/drift validator (`make lint-docs`)
```

## CONVENTIONS

- `production-verification.go`: Checks HTTP reachability, PostgreSQL, Prometheus targets, and ELK stack health. Run after any deploy via `go run scripts/production-verification.go`.
- `setup-filebeat.go`: Local tooling for filebeat setup. The remote execution payload `install-filebeat.sh` is SCP'd to hosts by TF provisioners (`lxc-config`/`vm-config`).
- `scaffold-workspace.go`: Creates new numbered workspace directories with README.md, AGENTS.md, main.tf, variables.tf, outputs.tf, versions.tf. Supports `--dry-run`.

## WHERE TO LOOK

| Task               | Script                                    | Notes                                            |
| ------------------ | ----------------------------------------- | ------------------------------------------------ |
| Verify Prod Health | `production-verification.go`              | Run after ANY deploy                             |
| Create PR          | `create-pr.go`                            | Enforces naming conventions                      |
| Backup state       | `backup-tfstate.go`                       | `make backup`; elk/synology/cloudflare only (pve state is in R2) |
| Audit workflows    | `audit-workflows.go`                      | `go run scripts/audit-workflows.go`; exit 1 on registry drift |
| Backup jobs        | `../100-pve/terraform/backup_jobs.tf`     | Terraform-owned PBS job declarations            |
| Deploy Filebeat    | `install-filebeat.sh`                     | Remote payload, SCP'd by TF provisioners         |
| Sync Vault         | `sync-vault-secrets.go`                   | `go run scripts/sync-vault-secrets.go --audit`   |
| Scaffold Workspace | `scaffold-workspace.go`                   | `go run scripts/scaffold-workspace.go 113 redis` |

## ANTI-PATTERNS

- **NO manual PR creation**: Use `create-pr.go` to ensure correct labelling.
- **NO ignoring verification failures**: If `production-verification.go` fails, rollback or fix immediately.
- **NO running install-filebeat.sh directly**: Use Terraform provisioner via CI/CD for consistent deployment.
- **NO running `make apply` locally**: `make apply` is disabled by repository policy. No apply or drift workflow currently exists in `.github/workflows/`.
