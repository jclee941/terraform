# AGENTS: .github — CI/CD Pipeline

## OVERVIEW
27 GitHub Actions workflows governing Terraform plan/apply, drift detection, PR automation, and security scanning. Reusable workflow pattern: `_terraform-{plan,apply}.yml` called by 12 service-specific workflows. All TF workflows run on `self-hosted` runner (LXC 101).

## STRUCTURE
```
.github/
├── workflows/
│   ├── _terraform-plan.yml    # Reusable: TF init + plan + PR comment
│   ├── _terraform-apply.yml   # Reusable: TF init + apply (on merge)
│   ├── terraform-plan.yml     # 100-pve plan (PR trigger)
│   ├── terraform-apply.yml    # 100-pve apply (push to master)
│   ├── terraform-drift.yml    # Daily drift check (7-workspace matrix)
│   ├── {svc}-plan.yml         # Per-service plan (6 services)
│   ├── {svc}-apply.yml        # Per-service apply (6 services)
│   ├── auto-merge.yml         # Risk-tier labeling + auto-merge (low only)
│   ├── pr-review.yml          # Automated PR review
│   ├── labeler.yml            # Auto-label by changed paths
│   ├── milestone-automation.yml
│   ├── secret-audit.yml       # Scan for exposed secrets
│   ├── security-scan.yml      # CodeQL + dependency scanning
│   ├── stale.yml              # Close stale issues/PRs
│   ├── onepassword-test.yml   # 1Password connectivity test
│   ├── worker-deploy.yml      # Cloudflare Worker deployment
│   └── internal-service-access.yml
└── actions/
    └── terraform-setup/       # Composite action: install TF + init
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Add Service Workflow** | Copy `{svc}-plan.yml` + `{svc}-apply.yml` | Call reusable `_terraform-plan/apply.yml` with service inputs. |
| **Drift Detection** | `terraform-drift.yml` | Matrix: proxmox, grafana, elk, traefik, archon, cloudflare, github. Daily 06:00 UTC. |
| **Risk Tiers** | `auto-merge.yml` | Critical (100-pve, modules, 300-cf, 301-gh, 102-traefik), medium (elk, supabase, archon, mcphub, oc, staging), low = auto-merge. |
| **Reusable Inputs** | `_terraform-plan.yml` | `service-name`, `working-directory`, `init-args`, `terraform-version`, `extra-env`. |
| **Secrets Pattern** | Reusable workflows | `_SECRETS → jq → TF_VAR_*` auto-export in plan/apply steps. |

## CONVENTIONS
- **Runner**: All TF workflows use `self-hosted` (LXC 101). Non-TF automation uses `ubuntu-latest`.
- **Backend Config**: Service workflows pass `-backend-config=../backend.hcl` (or `../../backend.hcl` for nested workspaces).
- **Pin Actions**: All `uses:` pinned to full commit SHA, not version tags.
- **Services**: archon, cloudflare, elk, github, grafana, traefik each have dedicated plan/apply pairs.

## ANTI-PATTERNS
- **NO `push` trigger** on plan workflows. Plans run on `pull_request` only.
- **NO secrets in logs**. Use `${{ secrets.* }}` with masked outputs.
- **NO `ubuntu-latest`** for TF workflows. Must use `self-hosted` for PVE/Vault network access.
- **NO manual workflow edits** without updating both plan AND apply counterparts.
