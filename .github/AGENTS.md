# AGENTS: .github — CI/CD Pipeline

## OVERVIEW

33 GitHub Actions workflows governing Terraform plan/apply, drift detection, PR automation, and security scanning. Includes 2 reusable `_terraform-*` templates and `opencode.yml` for dev VM config deployment. Each of the 7 TF workspaces has standalone plan/apply workflow pairs (~120 lines each). All TF workflows run on `self-hosted` runner (LXC 101).

## STRUCTURE

```
.github/
├── ISSUE_TEMPLATE/
│   ├── bug_report.yml          # Bug report template
│   ├── feature_request.yml     # Feature request template
│   ├── service_request.yml     # Service provisioning template
│   └── config.yml              # Template chooser config
├── pull_request_template.md    # Standardized PR template
├── copilot-review-instructions.md  # AI review guidelines
├── actionlint.yaml                # GitHub Actions linter config
├── workflows/
│   ├── _terraform-plan.yml     # Reusable plan template (called by service workflows)
│   ├── _terraform-apply.yml    # Reusable apply template (called by service workflows)
│   ├── terraform-plan.yml      # 100-pve plan (PR trigger)
│   ├── terraform-apply.yml     # 100-pve apply (push to master)
│   ├── terraform-drift.yml     # Drift check (Mon-Fri 00:00 UTC, 7-workspace matrix)
│   ├── {svc}-plan.yml          # Per-service plan (6 services: archon, cloudflare, elk, github, grafana, traefik)
│   ├── {svc}-apply.yml         # Per-service apply (6 services)
│   ├── auto-merge.yml          # Risk-tier labeling + auto-merge (low only)
│   ├── pr-review.yml           # Automated PR review
│   ├── labeler.yml             # Auto-label by changed paths
│   ├── milestone-automation.yml
│   ├── secret-audit.yml        # Scan for exposed secrets
│   ├── security-scan.yml       # CodeQL + dependency scanning
│   ├── stale.yml               # Close stale issues/PRs
│   ├── mcp-health-check.yml   # MCP server health monitoring
│   ├── onepassword-test.yml    # 1Password connectivity test
│   ├── worker-deploy.yml       # Cloudflare Worker deployment
│   ├── opencode.yml            # OpenCode dev VM config deployment
│   ├── terraform-docs.yml      # Auto-generate terraform-docs on PR
│   ├── tfstate-backup.yml      # Nightly tfstate backup to R2
│   └── internal-service-access.yml
└── actions/
    ├── terraform-setup/        # Composite action: install TF + init
    └── notify-failure/         # Composite action: issue creation + dedup
```

## WHERE TO LOOK

| Task                        | Location                                  | Notes                                                                                                                               |
| --------------------------- | ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **Add Service Workflow**    | Copy `{svc}-plan.yml` + `{svc}-apply.yml` | Standalone workflows per service. Each contains full TF init + plan/apply logic (~120 lines).                                       |
| **Drift Detection**         | `terraform-drift.yml`                     | Matrix: proxmox, grafana, elk, traefik, archon, cloudflare, github. Mon-Fri 00:00 UTC (09:00 KST).                                                |
| **Risk Tiers**              | `auto-merge.yml`                          | Critical (100-pve, modules, 300-cf, 301-gh, 102-traefik), medium (elk, supabase, archon, mcphub, 220-youtube), low = auto-merge.    |
| **Workflow Pattern**        | `{svc}-plan.yml`                          | Each standalone workflow has: TF setup, init, plan/apply, PR comment. No reusable workflow abstraction (consolidation opportunity). |
| **Secrets Pattern**         | Per-workflow steps                        | `secrets.*` → `TF_VAR_*` env export in plan/apply steps.                                                                            |
| **Custom action contracts** | `.github/actions/AGENTS.md`               | Shared inputs and anti-patterns for composite actions.                                                                              |
| **Issue Templates**         | `ISSUE_TEMPLATE/`                         | Bug, feature, and service request forms with structured fields.                                                                     |
| **PR Template**             | `pull_request_template.md`                | Standardized checklist for all pull requests.                                                                                       |
| **AI Review Guidelines**    | `copilot-review-instructions.md`          | Instructions for GitHub Copilot code review.                                                                                        |

## CONVENTIONS

- **Runner**: All TF workflows use `self-hosted` (LXC 101). Non-TF automation uses `ubuntu-latest`.
- **Backend Config**: All workspaces use local backend. No `-backend-config` needed — `terraform init` uses default local state.
- **Pin Actions**: All `uses:` pinned to full commit SHA, not version tags.
- **Services**: archon, cloudflare, elk, github, grafana, traefik each have dedicated standalone plan/apply pairs (~120 lines each, significant duplication — consolidation candidate).
- **Issue Templates**: Use YAML forms (not markdown) for structured input and automatic labeling.
- **Pre-deploy Verification**: `_terraform-plan.yml` runs `terraform validate` + `terraform fmt -check -recursive` before every plan. Gates propagate to all service workflows.
- **Post-deploy Verification**: `_terraform-apply.yml` runs `terraform validate` before apply and post-apply output validation after apply.
- **Manual Deploy Blocked**: `make apply` is disabled (exits 1). All applies must go through CI/CD workflows. `deploy-worker.sh` and `wrangler deploy` are also blocked.

## ANTI-PATTERNS

- **NO `push` trigger** on plan workflows. Plans run on `pull_request` only.
- **NO secrets in logs**. Use `${{ secrets.* }}` with masked outputs.
- **NO `ubuntu-latest`** for TF workflows. Must use `self-hosted` for PVE/Vault network access.
- **NO manual workflow edits** without updating both plan AND apply counterparts.
