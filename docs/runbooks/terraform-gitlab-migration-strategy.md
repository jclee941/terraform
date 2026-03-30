# Terraform Best Practice Modernization & GitLab Migration Strategy

**Generated:** 2026-03-30
**Scope:** Comprehensive migration plan from GitHub Actions to GitLab CI/CD with Terraform best practice adoption

---

## Executive Summary

This document outlines a phased approach to modernize the Terraform homelab infrastructure codebase and migrate from GitHub Actions to GitLab CI/CD. The migration preserves all existing functionality while improving reliability, security, and maintainability.

**Current State:**
- 21 Terraform workspaces across 4 tiers
- 72 GitHub Actions workflows (32 reusable + 40 standalone)
- Local state backend with git-based state tracking
- 1Password Connect for secret management
- Self-hosted runner on LXC 101

**Target State:**
- GitLab CI/CD with parallel pipeline optimization
- GitLab-managed Terraform state (HTTP backend)
- Consolidated workflow templates
- Enhanced security scanning and compliance

---

## Phase Overview

| Phase | Duration | Focus | Risk Level |
|-------|----------|-------|------------|
| 0 | 1-2 days | Analysis & Risk Assessment | Low |
| 1 | 3-5 days | Terraform Best Practices | Medium |
| 2 | 2-3 days | GitLab Infrastructure Setup | Medium |
| 3 | 5-7 days | Migration Execution | High |
| 4 | 2-3 days | Validation & Cleanup | Medium |

---

## Phase 0: Analysis & Risk Assessment

### 0.1 Critical Dependency Inventory

#### GitHub Actions Dependencies (89 workflow files)

**Core Terraform Workflows:**
```yaml
# Primary workflows requiring migration:
- terraform-plan.yml          # 100-pve PR plan
- terraform-apply.yml         # 100-pve master apply
- _terraform-plan.yml         # Reusable plan template (278 lines)
- _terraform-apply.yml        # Reusable apply template (512 lines)
- terraform-drift.yml         # 9-workspace matrix drift detection

# Service-specific plan/apply pairs (8 services):
- {archon,cloudflare,elk,github,grafana,ollama,slack,traefik}-plan.yml
- {archon,cloudflare,elk,github,grafana,ollama,slack,traefik}-apply.yml
```

**Automation & Governance Workflows:**
```yaml
- auto-merge.yml              # Risk-tier based auto-merge
- pr-review.yml               # PR automation
- security-scan.yml           # CodeQL + dependency scanning
- secret-audit.yml            # Secret exposure scanning
- terraform-docs.yml          # Auto-generated documentation
- tfstate-backup.yml          # Nightly state backup to R2
- credential-rotation.yml     # Secret rotation automation
```

#### Terraform GitHub Provider Resources

**301-github Workspace (Complete Removal Required):**
```hcl
# Resources to migrate or remove:
github_repository.repos                    # 18 repositories
github_repository_ruleset.branch           # Branch protection rules
github_repository_ruleset.tags             # Tag protection rules
github_repository_ruleset.code_scanning    # Code scanning rules
github_repository_webhook.webhooks         # Grafana/n8n webhooks
github_actions_repository_permissions      # Actions permissions
github_repository_dependabot_security_updates
```

**300-cloudflare Workspace (Partial):**
```hcl
# GitHub secrets management via 300-cloudflare/github-secrets.tf
github_actions_secret
# Target: Migrate to GitLab CI/CD variables or 1Password
```

#### Secrets & Environment Variables

**GitHub Actions Secrets (requires migration):**
```bash
GH_PAT                      # GitHub Personal Access Token
TF_API_TOKEN               # Terraform Cloud token (optional)
CLOUDFLARE_API_TOKEN       # Cloudflare API access
TF_VAR_GRAFANA_AUTH        # Grafana authentication
TF_VAR_N8N_WEBHOOK_URL     # n8n integration
TF_VAR_CLOUDFLARE_*        # Cloudflare configuration
TF_VAR_SYNOLOGY_DOMAIN     # Synology integration
TF_VAR_ACCESS_ALLOWED_EMAILS  # Access control
PROXMOX_VE_ENDPOINT        # Proxmox API endpoint
PROXMOX_VE_API_TOKEN       # Proxmox authentication
PROXMOX_VE_SSH_PRIVATE_KEY # Proxmox SSH access
OP_CONNECT_HOST            # 1Password Connect
OP_CONNECT_TOKEN           # 1Password authentication
```

### 0.2 Risk Assessment Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| State corruption during backend migration | Medium | Critical | Full backup, parallel runs, rollback procedure |
| Secret exposure during migration | Low | Critical | 1Password retention, gradual migration, audit logs |
| CI/CD downtime | Medium | High | Parallel runners, phased transition |
| Terraform provider compatibility | Low | Medium | Version pinning, testing environment |
| GitHub API rate limiting during export | Medium | Medium | Throttling, pagination, retry logic |

### 0.3 Rollback Strategy

**Immediate Rollback (< 1 hour):**
1. Restore GitHub Actions workflows from backup branch
2. Switch DNS/ingress back to GitHub (if changed)
3. Re-enable GitHub repository webhooks

**State Recovery:**
1. Local state backup: `terraform.tfstate.backup-YYYYMMDD-HHMMSS`
2. R2 backup: Nightly automated backups
3. Git history: All `.tfstate` files tracked in git

---

## Phase 1: Terraform Best Practice Adoption

### 1.1 State Backend Modernization

**Decision: GitLab-managed Terraform State**

Rationale:
- Native GitLab integration eliminates external dependencies
- Built-in state locking and versioning
- Access control via GitLab permissions
- No additional infrastructure required

**Implementation:**

```hcl
# backend.tf - To be added to each workspace
terraform {
  backend "http" {
    address        = "${GITLAB_TF_ADDRESS}/projects/${CI_PROJECT_ID}/terraform/state/${TF_WORKSPACE_NAME}"
    lock_address   = "${GITLAB_TF_ADDRESS}/projects/${CI_PROJECT_ID}/terraform/state/${TF_WORKSPACE_NAME}/lock"
    unlock_address = "${GITLAB_TF_ADDRESS}/projects/${CI_PROJECT_ID}/terraform/state/${TF_WORKSPACE_NAME}/lock"
    username       = "gitlab-ci-token"
    password       = "${CI_JOB_TOKEN}"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}
```

**Migration Script:**
```bash
#!/bin/bash
# scripts/migrate-state-backend.sh

WORKSPACES=("100-pve" "102-traefik/terraform" "104-grafana/terraform" "105-elk/terraform" "108-archon/terraform" "300-cloudflare" "301-github" "320-slack" "400-gcp")

for ws in "${WORKSPACES[@]}"; do
  echo "Migrating: $ws"
  cd "$ws" || continue

  # Backup current state
  cp terraform.tfstate "terraform.tfstate.backup-$(date +%Y%m%d-%H%M%S)"

  # Initialize with new backend
  TF_WORKSPACE_NAME=$(basename "$ws") \
  GITLAB_TF_ADDRESS="${GITLAB_TF_ADDRESS:-https://gitlab.com/api/v4}" \
  terraform init -migrate-state -input=false

  cd - > /dev/null
done
```

### 1.2 Module Structure Improvements

**Current Issues:**
- Duplicate workflow patterns across 8 services
- Hardcoded paths in config-renderer
- Limited input validation

**Recommended Changes:**

```hcl
# modules/shared/workspace-backend/main.tf
# New module for consistent backend configuration

variable "workspace_name" {
  description = "Name of the Terraform workspace"
  type        = string
}

variable "gitlab_project_id" {
  description = "GitLab project ID for state storage"
  type        = string
  default     = "${CI_PROJECT_ID}"
}

locals {
  backend_config = {
    address        = "${var.gitlab_tf_address}/projects/${var.gitlab_project_id}/terraform/state/${var.workspace_name}"
    lock_address   = "${var.gitlab_tf_address}/projects/${var.gitlab_project_id}/terraform/state/${var.workspace_name}/lock"
    unlock_address = "${var.gitlab_tf_address}/projects/${var.gitlab_project_id}/terraform/state/${var.workspace_name}/lock"
    username       = "gitlab-ci-token"
    password       = var.ci_job_token
  }
}

output "backend_config" {
  value     = local.backend_config
  sensitive = true
}
```

### 1.3 Testing Infrastructure Enhancement

**Current:** Basic `terraform test` on modules

**Enhanced Strategy:**
```yaml
# .gitlab-ci.yml test stages
stages:
  - validate
  - test
  - plan
  - apply
  - verify

validate:
  stage: validate
  script:
    - terraform fmt -check -recursive
    - terraform validate
    - tflint --recursive --format=compact
  parallel:
    matrix:
      - WORKSPACE: [100-pve, 102-traefik/terraform, 104-grafana/terraform]

test:
  stage: test
  script:
    - cd tests/modules/proxmox && terraform test
    - cd tests/modules/shared && terraform test
    - cd tests/integration && terraform test
```

---

## Phase 2: GitLab Infrastructure Setup

### 2.1 GitLab Runner Configuration

**Option A: Reuse Existing LXC 101 (Recommended)**

```bash
# On LXC 101 - Convert GitHub Actions runner to GitLab Runner
# 1. Unregister GitHub Actions runner
./config.sh remove --token ${GITHUB_RUNNER_TOKEN}

# 2. Install GitLab Runner
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | bash
apt-get install gitlab-runner

# 3. Register with GitLab
gitlab-runner register \
  --url https://gitlab.com \
  --registration-token ${GITLAB_REGISTRATION_TOKEN} \
  --executor shell \
  --tag-list "terraform,self-hosted,proxmox" \
  --locked=false \
  --access-level=not_protected

# 4. Configure for Terraform workloads
# /etc/gitlab-runner/config.toml
[[runners]]
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.machine]
    IdleCount = 0
    IdleTime = 0
```

**Option B: New GitLab Runner on LXC 113**

If keeping GitHub Actions runner during transition:
```hcl
# 100-pve/locals.tf - Add new runner
lxc_containers = {
  # ... existing containers ...
  gitlab_runner = {
    vmid        = 113
    hostname    = "gitlab-runner"
    ip          = "192.168.50.113"
    cores       = 2
    memory      = 2048
    disk_size   = 20
    description = "GitLab CI/CD Runner"
  }
}
```

### 2.2 GitLab CI/CD Pipeline Architecture

**Pipeline Structure:**

```yaml
# .gitlab-ci.yml (root level)
default:
  image: hashicorp/terraform:1.10.5
  tags:
    - terraform
    - self-hosted

variables:
  TF_ROOT: ${CI_PROJECT_DIR}
  TF_ADDRESS: ${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state

# Include modular pipeline definitions
include:
  - local: '.gitlab/ci/00-workspace-detection.yml'
  - local: '.gitlab/ci/10-validate.yml'
  - local: '.gitlab/ci/20-test.yml'
  - local: '.gitlab/ci/30-plan.yml'
  - local: '.gitlab/ci/40-apply.yml'
  - local: '.gitlab/ci/50-verify.yml'
  - local: '.gitlab/ci/60-drift-detection.yml'

# Workflow rules to control pipeline creation
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      when: always
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: always
    - if: $CI_COMMIT_TAG
      when: always
    - when: never
```

**Workspace Detection (Dynamic Child Pipelines):**

```yaml
# .gitlab/ci/00-workspace-detection.yml
generate-pipelines:
  stage: .pre
  script:
    - apk add --no-cache jq
    - |
      # Detect changed workspaces
      if [ "$CI_PIPELINE_SOURCE" == "merge_request_event" ]; then
        CHANGED_FILES=$(git diff --name-only origin/${CI_DEFAULT_BRANCH}...HEAD)
      else
        CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)
      fi

      # Map changed files to workspaces
      echo "$CHANGED_FILES" | python3 scripts/detect-workspaces.py > generated-pipelines.yml
  artifacts:
    paths:
      - generated-pipelines.yml
```

### 2.3 Secret Migration Strategy

**Approach: Hybrid (1Password + GitLab CI/CD Variables)**

Rationale:
- 1Password remains source of truth
- GitLab CI/CD variables for CI-specific tokens
- Reduces external API calls during pipelines

**Migration Steps:**

```bash
#!/bin/bash
# scripts/migrate-secrets-to-gitlab.sh

# 1. Export current GitHub Actions secrets
# (Requires GitHub CLI or API access)

echo "Exporting GitHub Actions secrets..."
gh secret list --json name --jq '.[].name' | while read -r secret_name; do
  value=$(gh secret get "$secret_name" --json value --jq '.value')

  # 2. Classify secret
  if [[ "$secret_name" == OP_* ]]; then
    # Keep in 1Password - no action needed
    echo "Skipping 1Password secret: $secret_name"
  elif [[ "$secret_name" == TF_VAR_* ]]; then
    # Add to GitLab as variable
    echo "Adding to GitLab: $secret_name"
    glab variable create --key "$secret_name" --value "$value" --protected
  else
    # Add to GitLab as secret (masked)
    echo "Adding to GitLab (masked): $secret_name"
    glab variable create --key "$secret_name" --value "$value" --masked --protected
  fi
done

# 3. Verify migration
glab variable list
```

---

## Phase 3: Migration Execution

### 3.1 Wave-Based Execution Plan

#### Wave 1: Foundation (Parallel) ⏱️ 1-2 days

| Task | Owner | Files | Verification |
|------|-------|-------|--------------|
| Create GitLab project | Admin | N/A | Project accessible, CI enabled |
| Setup GitLab Runner | DevOps | `/etc/gitlab-runner/config.toml` | Runner registered, tags assigned |
| Migrate 1Password connect | DevOps | `112-mcphub/docker-compose.yml` | Secrets accessible from GitLab |
| Create backup branch | Git | `backup/github-actions-2026-03-30` | Branch exists, workflows preserved |

#### Wave 2: Independent Workspaces (Parallel) ⏱️ 2-3 days

| Task | Owner | Files | Verification |
|------|-------|-------|--------------|
| Migrate 300-cloudflare | Terraform | `300-cloudflare/*`, remove `github-secrets.tf` | Plan succeeds, no GitHub refs |
| Migrate 320-slack | Terraform | `320-slack/*` | Plan succeeds |
| Migrate 400-gcp | Terraform | `400-gcp/*` | Plan succeeds |
| Deprecate 301-github | Terraform | Remove `301-github/` workspace | No GitHub provider refs |

#### Wave 3: Core Infrastructure (Sequential) ⏱️ 2-3 days

| Task | Owner | Dependencies | Verification |
|------|-------|--------------|--------------|
| Migrate 100-pve | Terraform | Wave 1 | LXC/VM state intact |
| Migrate 102-traefik | Terraform | 100-pve | Routes functional |
| Migrate 104-grafana | Terraform | 100-pve | Dashboards accessible |
| Migrate 105-elk | Terraform | 100-pve | Logs flowing |
| Migrate 108-archon | Terraform | 100-pve | RAG queries working |

#### Wave 4: Automation & Governance (Parallel) ⏱️ 2-3 days

| Task | Owner | Files | Verification |
|------|-------|-------|--------------|
| Drift detection | DevOps | `.gitlab/ci/60-drift-detection.yml` | Scheduled pipeline runs |
| Auto-merge | DevOps | `.gitlab/ci/merge-request-policies.yml` | MRs auto-merge on criteria |
| Security scanning | DevOps | `.gitlab-ci.yml` includes security jobs | Container scanning, SAST |
| Secret audit | DevOps | `.gitlab/ci/secret-audit.yml` | No secrets in code |

#### Wave 5: Template-Only Workspaces ⏱️ 1 day

| Task | Owner | Files | Verification |
|------|-------|-------|--------------|
| Update template rendering | Terraform | `modules/proxmox/config-renderer/*` | Configs generated correctly |
| Migrate runner configs | DevOps | `101-runner/*` | Runner configs deploy |
| Migrate remaining templates | Terraform | `107-supabase`, `109-gitops`, `110-n8n`, `112-mcphub` | Services operational |

### 3.2 GitHub Actions → GitLab CI Mapping

| GitHub Actions Concept | GitLab CI Equivalent | Notes |
|------------------------|---------------------|-------|
| `workflow_call` (reusable) | `include:` with local files | Native support, better composition |
| `concurrency` | `resource_group` | Pipeline-level serialization |
| `matrix` | `parallel: matrix` | Identical functionality |
| `environment` | `environment:` | Native environments with protection |
| `secrets.*` | `CI/CD Variables` | Project/group/instance levels |
| `actions/upload-artifact` | `artifacts:` | Native, simpler syntax |
| `actions/github-script` | `gitlab-script-trigger` or API calls | Custom scripting required |
| `pull_request` trigger | `merge_request_event` | Same concept |
| `push` to master | `CI_DEFAULT_BRANCH` | Same concept |
| `schedule` | `schedules` API | UI or API configuration |

### 3.3 Key Workflow Conversions

**Terraform Plan (Reusable):**

```yaml
# .gitlab/ci/30-plan.yml
.terraform_plan:
  stage: plan
  variables:
    TF_ROOT: ${CI_PROJECT_DIR}/${WORKSPACE_DIR}
    TF_PLAN_OUTPUT: plan.cache
  script:
    - cd ${TF_ROOT}
    - terraform init -input=false
    - terraform plan -input=false -out=${TF_PLAN_OUTPUT}
    - terraform show -json ${TF_PLAN_OUTPUT} > plan.json
  artifacts:
    paths:
      - ${TF_ROOT}/${TF_PLAN_OUTPUT}
      - ${TF_ROOT}/plan.json
    expire_in: 1 week
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
      allow_failure: true

# Service-specific plans (parallel matrix)
plan:workspaces:
  extends: .terraform_plan
  parallel:
    matrix:
      - WORKSPACE_DIR: "100-pve"
        WORKSPACE_NAME: "pve"
      - WORKSPACE_DIR: "102-traefik/terraform"
        WORKSPACE_NAME: "traefik"
      - WORKSPACE_DIR: "104-grafana/terraform"
        WORKSPACE_NAME: "grafana"
      - WORKSPACE_DIR: "105-elk/terraform"
        WORKSPACE_NAME: "elk"
      - WORKSPACE_DIR: "108-archon/terraform"
        WORKSPACE_NAME: "archon"
      - WORKSPACE_DIR: "300-cloudflare"
        WORKSPACE_NAME: "cloudflare"
      - WORKSPACE_DIR: "320-slack"
        WORKSPACE_NAME: "slack"
      - WORKSPACE_DIR: "400-gcp"
        WORKSPACE_NAME: "gcp"
```

**Drift Detection:**

```yaml
# .gitlab/ci/60-drift-detection.yml
drift:detection:
  stage: verify
  script:
    - |
      WORKSPACES=("100-pve" "102-traefik/terraform" "104-grafana/terraform" "105-elk/terraform" "108-archon/terraform" "300-cloudflare" "320-slack" "400-gcp")

      for ws in "${WORKSPACES[@]}"; do
        echo "Checking drift: $ws"
        cd "$CI_PROJECT_DIR/$ws"
        terraform init -input=false -backend=false

        if ! terraform plan -detailed-exitcode -input=false; then
          EXIT_CODE=$?
          if [ $EXIT_CODE -eq 2 ]; then
            echo "Drift detected in $ws"
            # Create GitLab issue
            glab issue create \
              --title "[Drift] Changes detected in $ws" \
              --label "terraform-drift,automated" \
              --description "Drift detected $(date). Run: make plan SVC=$ws"
          fi
        fi
      done
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
    - if: $CI_PIPELINE_SOURCE == "web"
  allow_failure: true
```

---

## Phase 4: Validation & Cleanup

### 4.1 Pre-Cutover Validation Checklist

- [ ] All 21 workspaces successfully plan in GitLab
- [ ] State backend migration verified (no data loss)
- [ ] All secrets accessible in GitLab CI/CD
- [ ] GitLab Runner performance validated (comparable to GHA)
- [ ] Drift detection schedule configured
- [ ] Rollback procedure tested
- [ ] Documentation updated

### 4.2 Cutover Procedure

**Step 1: Freeze GitHub Actions (Day 0, 00:00 UTC)**
```bash
# Disable all workflows via GitHub API
gh workflow list --json id | jq -r '.[].id' | while read -r id; do
  gh workflow disable "$id"
done
```

**Step 2: Final State Sync (Day 0, 00:30 UTC)**
```bash
# Ensure all states migrated
for ws in 100-pve 102-traefik/terraform 104-grafana/terraform 105-elk/terraform 108-archon/terraform 300-cloudflare 320-slack 400-gcp; do
  cd "$ws"
  terraform state pull > /tmp/verify-state.json
  # Verify state content
  cd -
done
```

**Step 3: Enable GitLab CI (Day 0, 01:00 UTC)**
- Remove `.gitlab-ci.yml` from `.gitignore` if present
- Push to GitLab
- Trigger initial pipeline

**Step 4: Validation (Day 0, 01:30 UTC)**
- Run full plan across all workspaces
- Verify no changes detected
- Check all services operational

### 4.3 Post-Cutover Cleanup

**Remove GitHub Actions (Week 2):**
```bash
# After 1 week stable operation
git rm -rf .github/workflows/
git rm -rf .github/actions/
git rm -rf .github/ISSUE_TEMPLATE/
git commit -m "chore: remove GitHub Actions after GitLab migration"
```

**Archive 301-github Workspace:**
```bash
# Remove GitHub provider workspace
git rm -rf 301-github/
git commit -m "chore: remove 301-github workspace (GitHub provider no longer needed)"
```

---

## Appendix A: File-Level Changes Reference

### A.1 Files to Create

```
.gitlab-ci.yml                          # Root pipeline configuration
.gitlab/ci/00-workspace-detection.yml   # Dynamic pipeline generation
.gitlab/ci/10-validate.yml              # Validation jobs
.gitlab/ci/20-test.yml                  # Testing jobs
.gitlab/ci/30-plan.yml                  # Plan jobs (parallel matrix)
.gitlab/ci/40-apply.yml                 # Apply jobs (protected)
.gitlab/ci/50-verify.yml                # Post-apply verification
.gitlab/ci/60-drift-detection.yml       # Scheduled drift checks
.gitlab/ci/variables.yml                # CI/CD variable definitions
scripts/migrate-state-backend.sh        # State migration helper
scripts/migrate-secrets-to-gitlab.sh    # Secret migration helper
docs/runbooks/gitlab-migration.md       # Migration runbook
```

### A.2 Files to Modify

```
# State backend migration (per workspace)
100-pve/main.tf                         # Add backend block
102-traefik/terraform/main.tf           # Add backend block
104-grafana/terraform/main.tf           # Add backend block
105-elk/terraform/main.tf               # Add backend block
108-archon/terraform/main.tf            # Add backend block
300-cloudflare/main.tf                  # Add backend block, remove GitHub refs
320-slack/main.tf                       # Add backend block
400-gcp/main.tf                         # Add backend block

# Remove or archive
301-github/                             # Entire workspace (archive)
300-cloudflare/github-secrets.tf        # Remove GitHub secrets management
.github/workflows/*.yml                 # Remove after migration
.github/actions/*/                      # Remove after migration
```

### A.3 Files to Archive (Not Delete)

```
.github/                                # Move to archive/github-backup/
  workflows/
  actions/
  ISSUE_TEMPLATE/
  AGENTS.md
```

---

## Appendix B: Decision Log

| Decision | Rationale | Date |
|----------|-----------|------|
| GitLab-managed state vs S3 | Native integration, no infra overhead, built-in locking | 2026-03-30 |
| Reuse LXC 101 vs new runner | Cost efficiency, proven stability, simpler migration | 2026-03-30 |
| Hybrid secrets (1P + GitLab) | Performance (fewer API calls), auditability, flexibility | 2026-03-30 |
| Remove 301-github vs migrate | No GitLab provider equivalent for all features, scope reduction | 2026-03-30 |
| Parallel workspace matrix | Faster feedback, independent workspaces | 2026-03-30 |

---

## Appendix C: Rollback Commands

```bash
# Emergency rollback to GitHub Actions
git checkout backup/github-actions-2026-03-30
git checkout -b emergency-rollback
git push origin emergency-rollback

# Restore GitHub Actions workflows
gh workflow enable terraform-plan.yml
gh workflow enable terraform-apply.yml

# Revert state backend (if migrated)
terraform init -migrate-state -backend-config="path=terraform.tfstate"
```

---

**Next Steps:**
1. Review and approve this strategy
2. Execute Phase 0 risk assessment
3. Create migration schedule with maintenance windows
4. Begin Phase 1 implementation
