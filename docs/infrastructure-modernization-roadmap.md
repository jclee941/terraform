# Infrastructure Modernization Roadmap

**Homelab Terraform Monorepo** | Generated: 2026-03-31  
**Status:** Planning Phase | **Target:** Full automation maturity

---

## Executive Summary

This roadmap outlines a phased approach to modernize the homelab infrastructure from its current **maturity level 6/10** to a fully automated, self-healing platform. The infrastructure currently manages 21 Terraform workspaces (11 active, 10 templates) across Proxmox, Cloudflare, and GCP with GitLab CI/CD.

**Current Pain Points:**
- Local Terraform state backend (no locking, committed to git)
- Hardcoded IPs bypassing the SSoT (`module.hosts`)
- 44% of workspaces lack CI/CD coverage
- No automated drift remediation
- Single points of failure (Proxmox node, 1Password Connect, GitLab runner)

**Target State:**
- Remote state backend with locking and versioning
- Dynamic configuration from SSoT
- 100% workspace coverage in CI/CD
- Automated drift detection and remediation
- HA architecture with failover capabilities

---

## Phase 1: IMMEDIATE WINS (This Week)

### P0-1: Fix Hardcoded IPs in Production Verification
**Priority:** P0 | **Effort:** S (4 hours) | **Impact:** HIGH

**Current State:**
```go
// scripts/production-verification.go:45-48
promHost := envOrDefault("PROM_HOST", "192.168.50.104")
grafanaHost := envOrDefault("GRAFANA_HOST", "192.168.50.104")
elkHost := envOrDefault("ELK_HOST", "192.168.50.105")
```

**Problem:** Hardcoded IPs bypass the `module.hosts` SSoT in `100-pve/envs/prod/hosts.tf`.

**Deliverables:**
- [ ] Read `100-pve/envs/prod/hosts.tf` outputs at verification runtime
- [ ] Fall back to environment variables, never hardcoded IPs
- [ ] Add validation that IPs match hosts.tf

**Implementation:**
```go
// Fetch IPs from Terraform outputs or remote state
type HostInventory struct {
    Hosts map[string]struct {
        IP string `json:"ip"`
    } `json:"hosts"`
}

func loadHostInventory() (*HostInventory, error) {
    // Read from 100-pve/terraform.tfstate or terraform output
}
```

**Success Criteria:**
- No hardcoded IPs in `production-verification.go`
- Changing IP in `hosts.tf` automatically updates verification
- CI passes with dynamic IP resolution

**Risk Mitigation:**
- Keep env var fallback for local testing
- Add IP format validation before use

---

### P0-2: Create Missing Drift Detection Runbook
**Priority:** P0 | **Effort:** S (2 hours) | **Impact:** HIGH

**Current State:** `docs/runbooks/drift-detection.md` referenced in ARCHITECTURE.md:200 but does not exist.

**Deliverables:**
- [ ] Create `docs/runbooks/drift-detection.md`
- [ ] Document drift detection pipeline stage
- [ ] Define manual drift reconciliation procedures
- [ ] Link to GitLab scheduled pipeline configuration

**Template Structure:**
```markdown
# Drift Detection Runbook

## Detection
- Scheduled: Mon-Fri 00:00 UTC via `.gitlab/ci/60-drift-detection.yml`
- Manual: `make drift-check` (disabled - use CI/CD)

## Alerting
- GitLab issue auto-created on drift detection
- Issue labeled `drift`, assigned to infrastructure team

## Reconciliation
1. Run `terraform plan` locally (read-only)
2. Identify drift source (manual UI change? external modification?)
3. If intentional: import resource or update Terraform config
4. If unintentional: `terraform apply` to correct

## Emergency Override
- If critical drift: manual apply via GitLab pipeline trigger
```

**Success Criteria:**
- Runbook exists and is discoverable from ARCHITECTURE.md
- On-call engineer can follow runbook without asking for help
- Links to GitLab pipeline and 100-pve workspace

---

### P0-3: Enable Blocking Verification Stage
**Priority:** P0 | **Effort:** S (1 hour) | **Impact:** MEDIUM

**Current State:**
```yaml
# .gitlab/ci/50-verify.yml
verify:deployment:
  allow_failure: true  # ❌ Doesn't block pipeline on failure
```

**Problem:** Failed health checks don't prevent broken deployments from reaching production.

**Deliverables:**
- [ ] Change `allow_failure: false` for critical verifications
- [ ] Add separate `verify:optional` job for non-critical checks
- [ ] Document which checks are critical vs optional

**Success Criteria:**
- Failed health check blocks deployment
- Pipeline shows red on verification failure
- Optional checks still allow_failure for experimental services

**Risk Mitigation:**
- Test on non-critical workspace first (300-cloudflare)
- Add `when: manual` option for emergency bypass

---

### P1-4: Add Security Scanning to CI Pipeline
**Priority:** P1 | **Effort:** S (4 hours) | **Impact:** HIGH

**Current State:** Security scanning only in pre-commit hooks (checkov, tfsec), not enforced in CI.

**Deliverables:**
- [ ] Add `checkov` job to validate stage
- [ ] Add `tfsec` job to validate stage
- [ ] Add `detect-secrets` scan to prepare stage
- [ ] Create `.checkov.yml` configuration file

**Implementation:**
```yaml
# .gitlab/ci/10-validate.yml (addition)
validate:security:
  stage: validate
  image: bridgecrew/checkov:latest
  script:
    - checkov --directory . --framework terraform --quiet
      --skip-path .archive --skip-path data --skip-path tests
      --skip-check CKV_TF_1  # Skip "Ensure Terraform module sources use a tag with a version"
  allow_failure: true  # Gradual rollout - make blocking after baseline
```

**Success Criteria:**
- Security scan runs on every MR
- Known issues documented with suppressions
- New security issues block merge (after baseline period)

---

### P1-5: Standardize Workspace Directory Structure
**Priority:** P1 | **Effort:** S (3 hours) | **Impact:** MEDIUM

**Current State:** Inconsistent structure:
- `100-pve/main.tf` (flat)
- `102-traefik/terraform/main.tf` (nested)

**Target Structure:**
```
{NNN}-{svc}/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── backend.tf
├── templates/
│   └── *.tftpl
├── docker-compose.yml
└── README.md
```

**Deliverables:**
- [ ] Migrate flat workspaces to `terraform/` subdirectory
- [ ] Update Makefile aliases
- [ ] Update `.gitlab/ci/*.yml` workspace paths
- [ ] Document standard structure in `docs/workspace-structure.md`

**Migration Order:**
1. 300-cloudflare (low risk, external)
2. 310-safetywallet
3. 320-slack
4. 400-gcp
5. 100-pve (highest risk, do last)

**Success Criteria:**
- All workspaces follow `/{workspace}/terraform/` pattern
- CI pipeline works for all workspaces
- `make plan SVC={workspace}` works for all

**Risk Mitigation:**
- Migrate one workspace at a time
- Verify CI passes before next migration
- Keep old path as symlink during transition (optional)

---

## Phase 2: SHORT-TERM (This Month)

### P0-6: Migrate to Remote Terraform State Backend
**Priority:** P0 | **Effort:** M (16 hours) | **Impact:** CRITICAL

**Current State:**
```hcl
# All versions.tf
backend "local" {}
```

**Problems:**
- No state locking (risk of concurrent modification)
- State committed to git (history exposure, merge conflicts)
- No state versioning or backup
- Can't use `terraform_remote_state` for cross-workspace dependencies

**Target:** GCS bucket with versioning and locking

**Deliverables:**
- [ ] Create GCS bucket `tfstate-homelab` with versioning
- [ ] Enable Object Lock for accidental deletion protection
- [ ] Create service account with minimal permissions
- [ ] Add `backend "gcs"` configuration to all workspaces
- [ ] Migrate existing state files
- [ ] Update `.gitignore` to exclude `.terraform/`
- [ ] Update CI/CD to authenticate to GCS

**Implementation:**
```hcl
# versions.tf (all workspaces)
terraform {
  required_version = ">= 1.7, < 2.0"
  
  backend "gcs" {
    bucket = "tfstate-homelab"
    prefix = "{workspace}"
    
    # Encryption at rest (CMEK optional)
    # kms_encryption_key = "projects/.../keyRings/.../cryptoKeys/..."
  }
}
```

**Migration Plan:**
1. Create GCS bucket with 30-day versioning
2. Start with independent workspaces (300-cloudflare, 400-gcp)
3. Migrate Tier 1 workspaces (102-traefik, 104-grafana)
4. Migrate Tier 0 (100-pve) last - requires coordination

**Success Criteria:**
- All workspaces use `backend "gcs"`
- State locking prevents concurrent applies
- State history visible in GCS versions
- CI/CD authenticates automatically via Workload Identity

**Risk Mitigation:**
- Backup all `.tfstate` files before migration
- Test on 300-cloudflare first
- Document rollback procedure (copy state back to local)
- Run migration during maintenance window for 100-pve

---

### P0-7: Implement Offsite Backup Replication
**Priority:** P0 | **Effort:** M (12 hours) | **Impact:** CRITICAL

**Current State:**
- Proxmox backups stored on PVE local storage only
- No offsite replication (acknowledged in `docs/backup-strategy.md:298-299`)
- SPOF: If PVE destroyed, backups lost

**Target:** 3-2-1 backup strategy (3 copies, 2 media, 1 offsite)

**Deliverables:**
- [ ] Set up Restic repository on offsite storage (Backblaze B2 or S3)
- [ ] Configure Proxmox backup job to sync to offsite
- [ ] Add backup verification job to CI/CD
- [ ] Document restore procedure from offsite
- [ ] Add monitoring for backup job success/failure

**Implementation:**
```bash
# Add to .gitlab/ci/50-verify.yml
verify:backups:
  stage: verify
  script:
    - restic -r b2:homelab-backups:/ snapshots --latest 1
    - restic -r b2:homelab-backups:/ check --read-data-subset=10%
```

**Success Criteria:**
- Backups replicated to offsite within 1 hour of local backup
- Monthly restore test from offsite documented
- Alert on backup failure (Grafana or GitLab)
- RTO documented for full PVE restoration

---

### P1-8: Expand Test Coverage to All Workspaces
**Priority:** P1 | **Effort:** M (8 hours) | **Impact:** MEDIUM

**Current State:** Only 5/10 CI-managed workspaces have tests:
- `tests/workspaces/pve/`
- `tests/workspaces/cloudflare/`
- `tests/workspaces/grafana/`
- `tests/workspaces/elk/`
- `tests/workspaces/slack/`

**Missing:** traefik, archon, synology, safetywallet, gcp

**Deliverables:**
- [ ] Add `tests/workspaces/traefik/`
- [ ] Add `tests/workspaces/archon/`
- [ ] Add `tests/workspaces/synology/`
- [ ] Add `tests/workspaces/safetywallet/`
- [ ] Add `tests/workspaces/gcp/`

**Template Structure:**
```hcl
# tests/workspaces/traefik/main.tftest.hcl
variables {
  workspace = "102-traefik"
}

run "validate_traefik_config" {
  command = plan
  
  assert {
    condition     = output.traefik_dashboard_url != ""
    error_message = "Traefik dashboard URL must be set"
  }
}
```

**Success Criteria:**
- All 10 CI-managed workspaces have test coverage
- Tests run in CI `test:workspaces` job
- Minimum 80% variable validation coverage

---

### P1-9: Implement Automated State Backup in CI/CD
**Priority:** P1 | **Effort:** S (4 hours) | **Impact:** MEDIUM

**Current State:**
- `make backup` runs `backup-tfstate.go` manually
- No automated backup before/after apply
- Only 100-pve state is backed up

**Deliverables:**
- [ ] Add `backup:state` job to apply stage
- [ ] Backup state before and after each apply
- [ ] Store backups in GCS with timestamp
- [ ] Add 30-day retention policy

**Implementation:**
```yaml
# .gitlab/ci/40-apply.yml (addition)
apply:all:
  before_script:
    - go run scripts/backup-tfstate.go --workspace=$TF_WORKSPACE --pre-apply
  script:
    - terraform apply -auto-approve tfplan
  after_script:
    - go run scripts/backup-tfstate.go --workspace=$TF_WORKSPACE --post-apply
```

**Success Criteria:**
- State backed up before every apply
- State backed up after successful apply
- Backups retained for 30 days
- Can restore to any point in last 30 days

---

### P2-10: Implement Cost Estimation (Infracost)
**Priority:** P2 | **Effort:** S (4 hours) | **Impact:** LOW

**Deliverables:**
- [ ] Add Infracost to plan stage
- [ ] Comment cost delta on MRs
- [ ] Set up budget alerts

**Implementation:**
```yaml
plan:infracost:
  stage: plan
  image: infracost/infracost:latest
  script:
    - infracost breakdown --path . --format json --out-file infracost.json
    - infracost comment gitlab --path infracost.json --repo $CI_PROJECT_PATH --merge-request $CI_MERGE_REQUEST_IID
```

---

## Phase 3: MID-TERM (This Quarter)

### P1-11: Version Modules with Git Tags
**Priority:** P1 | **Effort:** M (12 hours) | **Impact:** HIGH

**Current State:**
```hcl
# All workspaces
module "lxc" {
  source = "../modules/proxmox/lxc"  # No version!
}
```

**Problem:** Module changes immediately affect all consumers. No way to roll out gradually.

**Target:** Use Git tags for module versioning

**Deliverables:**
- [ ] Create Git tags for module versions (`modules/proxmox/lxc/v1.0.0`)
- [ ] Update all workspaces to use versioned sources
- [ ] Document module release process
- [ ] Add module changelog

**Implementation:**
```hcl
module "lxc" {
  source = "git::https://gitlab.com/qws941/terraform.git//modules/proxmox/lxc?ref=modules/proxmox/lxc/v1.2.0"
}
```

**Alternative:** Use GitLab Terraform Registry

**Success Criteria:**
- All module calls use versioned sources
- Can update module without breaking all workspaces
- Module changelog documents breaking changes

---

### P1-12: Extract Host Inventory to Standalone Module
**Priority:** P1 | **Effort:** M (16 hours) | **Impact:** HIGH

**Current State:**
- `100-pve/envs/prod/hosts.tf` is SSoT but nested inside 100-pve workspace
- Tight coupling: can't change hosts without applying 100-pve

**Target:** Standalone `modules/shared/hosts/` module

**Deliverables:**
- [ ] Create `modules/shared/hosts/` module
- [ ] Move host definitions from `100-pve/envs/prod/hosts.tf`
- [ ] Update 100-pve to use new module
- [ ] Update all workspaces to use host module outputs
- [ ] Remove `envs/prod/` directory

**Module Interface:**
```hcl
module "hosts" {
  source = "../modules/shared/hosts"
}

# Usage
module "lxc" {
  source = "../modules/proxmox/lxc"
  ip     = module.hosts.hosts["traefik"].ip
}
```

**Success Criteria:**
- Host inventory is standalone module
- Can modify hosts without applying 100-pve
- All workspaces use `module.hosts` consistently

---

### P2-13: Implement Automated Drift Remediation
**Priority:** P2 | **Effort:** L (24 hours) | **Impact:** HIGH

**Current State:**
- Drift detected by scheduled pipeline
- GitLab issue auto-created
- Manual intervention required to remediate

**Target:** Auto-remediate non-critical drift

**Deliverables:**
- [ ] Classify drift types (critical vs non-critical)
- [ ] Auto-apply non-critical drift
- [ ] Create MR for critical drift with remediation plan
- [ ] Add drift trend dashboard in Grafana

**Implementation:**
```yaml
# .gitlab/ci/60-drift-detection.yml (addition)
drift:remediate:
  stage: drift-detection
  script:
    - terraform plan -detailed-exitcode -out=drift.tfplan || exit_code=$?
    - |
      if [ $exit_code -eq 2 ]; then
        # Drift detected - check if auto-remediable
        if terraform show -json drift.tfplan | jq -e '.resource_changes[] | select(.change.actions[] | contains("delete"))'; then
          echo "Critical drift detected - requires manual review"
          exit 1
        else
          echo "Non-critical drift - auto-remediating"
          terraform apply -auto-approve drift.tfplan
        fi
      fi
```

**Risk Mitigation:**
- Only auto-remediate after 30-day observation period
- Require manual approval for resource deletions
- Alert on all auto-remediation actions

---

### P2-14: Centralize Template Registry
**Priority:** P2 | **Effort:** M (12 hours) | **Impact:** MEDIUM

**Current State:**
- 52 `.tftpl` files scattered across 10 workspaces
- `_svc_tpl` map in `100-pve/locals.tf` is 270+ lines
- No centralized template management

**Target:** `modules/shared/templates/` with versioned templates

**Deliverables:**
- [ ] Create `modules/shared/templates/` directory
- [ ] Move all `.tftpl` files to central location
- [ ] Update `config-renderer` module to use centralized templates
- [ ] Add template versioning
- [ ] Document template authoring guidelines

**Success Criteria:**
- All templates in one location
- Template changes versioned independently
- Workspaces reference templates by version

---

### P2-15: Add Automated Rollback Mechanism
**Priority:** P2 | **Effort:** M (16 hours) | **Impact:** MEDIUM

**Current State:**
- No rollback on apply failure
- Manual intervention required

**Deliverables:**
- [ ] Capture pre-apply state
- [ ] On failure, offer rollback to previous state
- [ ] Add `rollback` job to deploy stage
- [ ] Document rollback procedures

**Implementation:**
```yaml
deploy:rollback:
  stage: deploy
  when: manual
  script:
    - gsutil cp gs://tfstate-homelab-backups/$TF_WORKSPACE-$(date -d '1 hour ago' +%Y%m%d-%H%M%S).tfstate .
    - terraform state replace-provider -auto-approve
    - terraform apply -state=backup.tfstate -auto-approve
```

---

## Phase 4: LONG-TERM (This Year)

### P2-16: Implement Workspace-Specific Pipelines
**Priority:** P2 | **Effort:** L (32 hours) | **Impact:** HIGH

**Current State:**
- Matrix jobs run for all workspaces on every change
- Wastes CI minutes on unchanged workspaces

**Target:** Trigger only affected workspaces via `workflow:rules:changes`

**Deliverables:**
- [ ] Add `workflow:rules:changes` to detect affected workspaces
- [ ] Generate dynamic child pipelines per workspace
- [ ] Maintain tier ordering (100-pve before Tier 1)
- [ ] Visualize pipeline dependencies

**Implementation:**
```yaml
# Dynamic pipeline generation
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes:
        - 100-pve/**/*
      when: always
    - if: $CI_PIPELINE_SOURCE == "schedule"
      when: always
    - when: never

generate-pipeline:
  script:
    - go run scripts/generate-workspace-pipeline.go --changed-files="$CI_MERGE_REQUEST_CHANGED_FILES"
    - cat generated-pipeline.yml | tee child-pipeline.yml
  artifacts:
    paths:
      - child-pipeline.yml

trigger-child:
  trigger:
    include:
      - artifact: child-pipeline.yml
```

**Success Criteria:**
- Only changed workspaces run in CI
- Pipeline time reduced by 50%+
- Tier ordering preserved

---

### P2-17: Implement Multi-Node Proxmox Support
**Priority:** P2 | **Effort:** L (40 hours) | **Impact:** CRITICAL

**Current State:**
- Single Proxmox node: `pve3`
- No HA/failover capability
- SPOF for entire infrastructure

**Target:** 3-node Proxmox cluster with HA

**Deliverables:**
- [ ] Add 2 additional Proxmox nodes
- [ ] Configure cluster with quorum
- [ ] Enable HA for critical LXCs (traefik, mcphub)
- [ ] Update modules to support node selection
- [ ] Add node health monitoring

**Implementation:**
```hcl
# modules/proxmox/lxc/variables.tf
variable "node_name" {
  type    = string
  default = "pve3"
  
  validation {
    condition     = contains(["pve1", "pve2", "pve3"], var.node_name)
    error_message = "Node must be pve1, pve2, or pve3"
  }
}

# Enable HA migration
resource "proxmox_virtual_environment_lxc" "this" {
  # ...
  
  lifecycle {
    ignore_changes = [
      # Allow HA to migrate between nodes
      node_name,
    ]
  }
}
```

**Success Criteria:**
- 3-node cluster operational
- Critical services have HA enabled
- Node failure triggers automatic migration
- Single node maintenance possible without downtime

**Risk Mitigation:**
- Add nodes one at a time
- Test HA failover before marking critical
- Document node maintenance procedures

---

### P3-18: Implement 1Password Connect HA
**Priority:** P3 | **Effort:** M (16 hours) | **Impact:** MEDIUM

**Current State:**
- Single 1Password Connect server on LXC 112
- If mcphub down, no secret access

**Target:** HA 1Password Connect with failover

**Deliverables:**
- [ ] Deploy secondary Connect server
- [ ] Configure load balancer
- [ ] Add health checks
- [ ] Document failover procedure

---

### P3-19: Implement Self-Healing Infrastructure
**Priority:** P3 | **Effort:** XL (80 hours) | **Impact:** HIGH

**Current State:**
- Manual intervention for service failures
- No automatic recovery

**Target:** Self-healing with n8n + Prometheus alerts

**Deliverables:**
- [ ] Define health criteria for each service
- [ ] Create n8n workflows for auto-remediation
- [ ] Implement circuit breakers
- [ ] Add chaos engineering tests

**Auto-Remediation Scenarios:**
- Service down → Restart container
- Disk full → Clean old logs
- High memory → Scale up or restart
- Certificate expiry → Auto-renew

---

### P3-20: Implement GitOps-Style Deployments
**Priority:** P3 | **Effort:** L (32 hours) | **Impact:** MEDIUM

**Current State:**
- MR triggers plan
- Manual approval triggers apply

**Target:** Full GitOps - merge to main auto-applies

**Deliverables:**
- [ ] Add automated apply on merge
- [ ] Implement canary deployments
- [ ] Add auto-rollback on failure
- [ ] Remove manual approval gates

**Risk Mitigation:**
- Require 2 approvals before auto-apply
- Run full test suite before apply
- Keep manual approval for Tier 0 (100-pve)

---

## Implementation Roadmap Summary

### Q1 2026 (This Quarter)

| Week | Initiatives |
|------|-------------|
| 1 | P0-1 Fix hardcoded IPs, P0-2 Create drift runbook, P0-3 Enable blocking verification |
| 2 | P0-6 Remote state backend (start with 300-cloudflare), P0-7 Offsite backups |
| 3 | P0-6 Continue backend migration (Tier 1 workspaces), P1-8 Expand test coverage |
| 4 | P0-6 Complete backend migration (100-pve), P1-9 Automated state backup |

### Q2 2026

| Month | Initiatives |
|-------|-------------|
| April | P1-11 Module versioning, P1-12 Extract host inventory |
| May | P2-13 Automated drift remediation, P2-14 Centralize templates |
| June | P2-15 Automated rollback, P2-16 Workspace-specific pipelines |

### Q3 2026

| Month | Initiatives |
|-------|-------------|
| July | P2-17 Multi-node Proxmox (node addition) |
| August | P2-17 HA configuration, P3-18 1Password Connect HA |
| September | P3-19 Self-healing infrastructure (phase 1) |

### Q4 2026

| Month | Initiatives |
|-------|-------------|
| October | P3-19 Self-healing infrastructure (phase 2) |
| November | P3-20 GitOps deployments |
| December | Chaos engineering, disaster recovery drills |

---

## Success Metrics

### Automation Maturity Score

| Dimension | Current | Q1 Target | Q2 Target | Q4 Target |
|-----------|---------|-----------|-----------|-----------|
| Coverage | 6/10 | 7/10 | 8/10 | 9/10 |
| Parallelization | 7/10 | 7/10 | 8/10 | 9/10 |
| Security | 4/10 | 6/10 | 7/10 | 8/10 |
| Testing | 5/10 | 6/10 | 7/10 | 8/10 |
| Verification | 6/10 | 7/10 | 7/10 | 9/10 |
| Drift Detection | 7/10 | 7/10 | 8/10 | 9/10 |
| Secret Management | 8/10 | 8/10 | 8/10 | 9/10 |
| Documentation | 6/10 | 7/10 | 7/10 | 8/10 |
| Local Dev Ergonomics | 8/10 | 8/10 | 8/10 | 8/10 |
| Recovery/Rollback | 3/10 | 5/10 | 7/10 | 9/10 |
| **Overall** | **6.0/10** | **6.8/10** | **7.5/10** | **8.6/10** |

### Key Performance Indicators

| KPI | Current | Target (Q4) |
|-----|---------|-------------|
| CI Pipeline Duration | ~45 min | <20 min |
| Deployment Frequency | 2-3/week | Daily |
| Mean Time to Recovery | Hours | <15 min |
| Drift Detection Latency | 24 hours | 5 minutes |
| Test Coverage | 28% (5/18) | 80% (14/18) |
| Security Scan Pass Rate | N/A (no CI scan) | 95% |
| Documentation Coverage | 70% | 95% |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| State migration failure | Medium | Critical | Full backup, rollback plan, test on independent workspace first |
| Remote backend unavailable | Low | Critical | Local state backup as fallback, documented manual procedure |
| Multi-node cluster complexity | Medium | High | Gradual rollout, extensive testing, maintenance windows |
| Auto-remediation causes damage | Low | High | Start with read-only, gradual enablement, comprehensive monitoring |
| Module versioning confusion | Medium | Medium | Clear changelog, migration guide, deprecation notices |
| CI pipeline complexity | Medium | Medium | Documentation, runbooks, dry-run capability |

---

## Resource Requirements

### Compute
- Additional 2 Proxmox nodes (for HA)
- GCS bucket storage (tfstate + backups)
- Backblaze B2 or S3 (offsite backups)

### Time
- Q1: 40 hours (1 week FTE)
- Q2: 80 hours (2 weeks FTE)
- Q3: 120 hours (3 weeks FTE)
- Q4: 120 hours (3 weeks FTE)
- **Total: 360 hours (~9 weeks FTE)**

### Tools
- Infracost (cost estimation)
- Checkov/TFSec (security scanning)
- Restic (backup tool - already in use)

---

## Appendix A: Dependencies Graph

```
P0-1 Fix hardcoded IPs
  └─ No dependencies

P0-2 Create drift runbook
  └─ No dependencies

P0-3 Enable blocking verification
  └─ Depends on: P0-1 (verification uses dynamic IPs)

P0-6 Remote state backend
  └─ No dependencies (can start with 300-cloudflare)
  └─ Blocks: P1-9 (automated state backup)

P0-7 Offsite backup replication
  └─ No dependencies

P1-8 Expand test coverage
  └─ No dependencies

P1-9 Automated state backup
  └─ Depends on: P0-6 (remote backend)

P1-11 Module versioning
  └─ Depends on: P1-12 (host inventory extraction - reduces module coupling)

P1-12 Extract host inventory
  └─ Depends on: P0-6 (remote backend for cross-workspace data)

P2-13 Automated drift remediation
  └─ Depends on: P0-6 (remote backend for state access)
  └─ Depends on: P2-15 (rollback mechanism)

P2-16 Workspace-specific pipelines
  └─ Depends on: P1-12 (host inventory as module - reduces cross-workspace deps)

P2-17 Multi-node Proxmox
  └─ No dependencies
  └─ Blocks: P3-18 (Connect HA - needs node diversity)
```

---

## Appendix B: Rollback Procedures

### State Backend Migration Rollback

If remote backend migration fails:

```bash
# 1. Stop all CI pipelines
# 2. Restore local state from backup
cp backup/100-pve-*.tfstate 100-pve/terraform.tfstate

# 3. Update backend configuration
# Edit versions.tf to use backend "local" {}

# 4. Re-initialize
terraform init -migrate-state

# 5. Verify state
cd 100-pve && terraform state list

# 6. Resume CI
```

### Drift Remediation Rollback

If automated drift remediation causes issues:

```bash
# 1. Identify last known good state
gsutil ls gs://tfstate-homelab-backups/100-pve-*

# 2. Restore state
gsutil cp gs://tfstate-homelab-backups/100-pve-<timestamp>.tfstate .
terraform state replace-provider -auto-approve
terraform apply -state=backup.tfstate

# 3. Disable auto-remediation
# Edit .gitlab/ci/60-drift-detection.yml
# Set allow_failure: true for drift:remediate
```

---

**Document Owner:** Infrastructure Team  
**Review Schedule:** Monthly  
**Next Review:** 2026-04-30
