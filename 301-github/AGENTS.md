# AGENTS: 301-github — GitHub Organization Management

## OVERVIEW
Terraform workspace managing GitHub resources for `qws941`. Provisions 17 repositories, branch protection rulesets (3 tiers: strict/standard/minimal), Actions permissions, webhooks (n8n integration), environments, deploy keys, teams, and security scanning (Dependabot + CodeQL). Provider: `integrations/github` (~>6.6).

## STRUCTURE
```
301-github/
├── main.tf              # Provider config (github)
├── versions.tf          # Backend (S3/R2) + remote state from 100-pve
├── variables.tf         # 380+ lines: repo list, actions, teams, secrets
├── repositories.tf      # 17 repos with visibility, topics, protection tier
├── rulesets.tf          # 3 protection profiles (strict/standard/minimal)
├── actions.tf           # Org + per-repo Actions permissions, secrets, variables
├── environments.tf      # Deployment environments with reviewers + secrets
├── webhooks.tf          # 4 n8n webhooks per non-archived repo
├── deploy-keys.tf       # SSH deploy keys per repo
├── teams.tf             # Org teams, memberships, repo access (org-only)
├── security.tf          # Dependabot + CodeQL scanning rulesets
├── branch-protection.tf # Legacy branch protection (pre-rulesets)
├── repository-files.tf  # Managed files pushed to repos
├── onepassword.tf       # 1Password secret lookup (via shared module)
├── validation.tf        # Input validation rules
├── data.tf              # Data sources (user, existing repos)
├── locals.tf            # Shared locals
├── import.tf            # State imports for existing resources
└── outputs.tf           # Exported values
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Add Repository** | `repositories.tf` | Add to `local.repositories` map + `known_repositories` in variables.tf. |
| **Protection Tier** | `rulesets.tf` | `protection_profiles`: strict (2 approvers, CODEOWNERS), standard (1), minimal. |
| **Actions Secrets** | `actions.tf` | Per-repo via `repository_actions_secrets` variable. Flattened to `*_flat` locals. |
| **Webhooks** | `webhooks.tf` | 4 n8n hooks: glitchtip-error, grafana-alert, github-issue, github-pr. |
| **Environments** | `environments.tf` | Deployment envs with wait timers, reviewers, branch policies. |
| **Security** | `security.tf` | Dependabot auto-updates + CodeQL scanning rulesets. |
| **1Password Secrets** | `onepassword.tf` + `validation.tf` | Structured secret lookup via `modules/shared/onepassword-secrets`. |
| **Remote State** | `versions.tf` | Consumes 100-pve outputs via `terraform_remote_state.infra`. |

## CONVENTIONS
- **Org Toggle**: `manage_as_organization = false` disables teams/org-level resources for personal accounts.
- **Webhook URLs**: Derived from `local.n8n_webhook_urls`. Blank URL = webhook skipped.
- **Flat Locals**: Complex nested vars flattened to `*_flat` locals for `for_each`.
- **Risk Tier**: This workspace is `risk:critical` — manual merge required.

## ANTI-PATTERNS
- **NO manual repo settings** via GitHub UI for TF-managed repos. Causes drift.
- **NO plaintext secrets** in tfvars. Use `sensitive = true` variables.
- **NO duplicate keys** in locals/maps. HCL silently uses last definition — bugs are invisible.

## COMMANDS
```bash
make plan SVC=github          # Plan changes
make apply SVC=github         # Apply
```
