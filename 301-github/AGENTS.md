# AGENTS: 301-github — GitHub Organization Management

## OVERVIEW
Terraform workspace managing GitHub resources for `qws941`. Provisions 17 repositories, branch protection rulesets (3 tiers: strict/standard/minimal), webhooks (n8n integration), environments, deploy keys, teams, org/repo secrets and variables, and security scanning (Dependabot + CodeQL). Provider: `integrations/github` (~>6.6).

## STRUCTURE
```
301-github/
├── main.tf              # Provider config (github)
├── versions.tf          # Backend (S3/R2) + remote state from 100-pve
├── variables.tf         # Inputs: repos, teams, webhooks, security, environments
├── actions.tf           # Org/repo secrets and variables (no policy/runner mgmt)
├── repositories.tf      # 17 repos with visibility, topics, protection tier
├── rulesets.tf          # 3 protection profiles (strict/standard/minimal)
├── environments.tf      # Deployment environments with secrets/variables
├── webhooks.tf          # 3 n8n webhooks per non-archived repo
├── deploy-keys.tf       # SSH deploy keys per repo
├── teams.tf             # Org teams, memberships, repo access (org-only)
├── security.tf          # Dependabot + CodeQL scanning rulesets
├── repository-files.tf  # Managed files pushed to repos
├── onepassword.tf       # 1Password secret lookup (via shared module)
├── validation.tf        # Input validation rules
├── locals.tf            # Shared locals
├── locals.tf            # Shared locals
├── import.tf            # State imports for existing resources
├── outputs.tf           # Exported values
└── tests/               # Workspace validation tests (github_test.tftest.hcl)
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Add Repository** | `repositories.tf` | Add to `local.repositories` map + `known_repositories` in variables.tf. |
| **Protection Tier** | `rulesets.tf` | `protection_profiles`: strict (2 approvers, CODEOWNERS), standard (1), minimal. |
| **Environments** | `environments.tf` | Deployment envs with wait timers, reviewers, branch policies, secrets, variables. |
| **Actions Secrets/Variables** | `actions.tf` | Org-level and per-repo GitHub Actions secrets and variables. |
| **Security** | `security.tf` | Dependabot auto-updates + CodeQL scanning rulesets. |
| **1Password Secrets** | `onepassword.tf` + `validation.tf` | Structured secret lookup via `modules/shared/onepassword-secrets`. |
| **Workspace Tests** | `tests/github_test.tftest.hcl` | Variable validation tests for this workspace. |
| **Remote State** | `versions.tf` | Consumes 100-pve outputs via `terraform_remote_state.infra`. |

## CONVENTIONS
- **Org Toggle**: `manage_as_organization = false` disables teams, org secrets/variables for personal accounts.
- **CI Guardrail**: Apply workflow auto-prunes org-only state (teams/org secrets/variables) when the GitHub owner is a user to avoid `github_team` refresh failures.
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
