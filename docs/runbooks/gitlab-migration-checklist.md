# Terraform GitLab Migration Checklist

**Migration Date:** ___________
**Lead Engineer:** ___________
**Rollback Contact:** ___________

---

## Phase 0: Pre-Migration (Complete BEFORE cutover)

### Risk Assessment
- [ ] Review all GitHub Actions workflows (72 files)
- [ ] Document all GitHub-specific secrets and variables
- [ ] Identify GitHub provider resources in 301-github
- [ ] Assess Cloudflare GitHub secrets integration
- [ ] Create rollback plan and test procedure

### Infrastructure Setup
- [ ] GitLab project created and configured
- [ ] GitLab Runner registered on LXC 101 (or 113)
- [ ] Runner tags: `terraform`, `self-hosted`, `proxmox`
- [ ] 1Password Connect accessible from GitLab Runner
- [ ] Verify network connectivity (192.168.50.x from runner)

### Secret Migration
- [ ] Export GitHub Actions secrets inventory
- [ ] Create CI/CD variables in GitLab (project level)
- [ ] Mask sensitive variables (tokens, passwords)
- [ ] Protect variables for default branch only
- [ ] Test secret access from GitLab CI

### State Backup
- [ ] Full backup of all `.tfstate` files
- [ ] Verify R2 backup is current
- [ ] Create backup branch: `backup/github-actions-YYYY-MM-DD`
- [ ] Document state file locations

---

## Phase 1: Terraform Best Practices

### State Backend (Optional Enhancement)
- [ ] Decide: Keep local state or migrate to GitLab-managed
- [ ] If migrating, test backend migration in dev environment
- [ ] Document backend configuration for each workspace
- [ ] Verify state locking mechanism (concurrency groups)

### Module Improvements
- [ ] Review module structure
- [ ] Add input validation where missing
- [ ] Update module documentation
- [ ] Run `terraform fmt` on all files

### Testing
- [ ] Verify all module tests pass
- [ ] Run integration tests
- [ ] Run workspace validation tests
- [ ] Document test coverage gaps

---

## Phase 2: GitLab CI Setup

### Pipeline Configuration
- [ ] Root `.gitlab-ci.yml` committed
- [ ] Modular CI files in `.gitlab/ci/` created
  - [ ] `00-prepare.yml`
  - [ ] `10-validate.yml`
  - [ ] `20-test.yml`
  - [ ] `30-plan.yml`
  - [ ] `40-apply.yml`
  - [ ] `50-verify.yml`
  - [ ] `60-drift-detection.yml`

### Workspace Coverage
- [ ] 100-pve (core infrastructure)
- [ ] 102-traefik/terraform
- [ ] 104-grafana/terraform
- [ ] 105-elk/terraform
- [ ] 108-archon/terraform
- [ ] 215-synology
- [ ] 300-cloudflare
- [ ] 310-safetywallet
- [ ] 320-slack
- [ ] 400-gcp

### Pipeline Testing
- [ ] Test MR pipeline (validate + plan)
- [ ] Test default branch pipeline
- [ ] Verify artifacts are created correctly
- [ ] Test manual apply job
- [ ] Verify resource groups prevent parallel applies

---

## Phase 3: Migration Execution

### Pre-Cutover (Day -1)
- [ ] Announce maintenance window
- [ ] Freeze all infrastructure changes
- [ ] Disable GitHub Actions workflows
- [ ] Final state backup
- [ ] Verify GitLab CI is ready

### Cutover Day (Day 0)

#### 00:00 - 01:00 UTC: Final Preparations
- [ ] Disable GitHub Actions workflows via API
- [ ] Verify no running GitHub Actions jobs
- [ ] Sync code to GitLab (if not using GitLab as primary)

#### 01:00 - 02:00 UTC: State Verification
- [ ] Run `terraform plan` on all workspaces in GitLab
- [ ] Verify no unexpected changes
- [ ] Document any drift

#### 02:00 - 03:00 UTC: Go Live
- [ ] Enable GitLab CI pipeline
- [ ] Trigger first pipeline
- [ ] Verify all stages complete successfully
- [ ] Spot-check key infrastructure (Traefik, Grafana)

#### 03:00 - 04:00 UTC: Validation
- [ ] Run verification scripts
- [ ] Check service health endpoints
- [ ] Verify 1Password Connect accessible
- [ ] Confirm log aggregation working

### Post-Cutover
- [ ] Monitor for 24 hours
- [ ] Document any issues
- [ ] Verify scheduled drift detection runs
- [ ] Update team documentation

---

## Phase 4: Cleanup

### GitHub Removal (Week 2, after stable operation)
- [ ] Archive GitHub Actions workflows
- [ ] Remove `.github/workflows/` directory
- [ ] Archive 301-github workspace
- [ ] Update documentation references

### Documentation Updates
- [ ] Update `AGENTS.md` files
- [ ] Update `ARCHITECTURE.md`
- [ ] Update runbooks
- [ ] Update onboarding docs

### Knowledge Transfer
- [ ] Demo GitLab CI to team
- [ ] Document troubleshooting procedures
- [ ] Share rollback procedure
- [ ] Update incident response playbooks

---

## Verification Matrix

| Workspace | Validate | Plan | Apply | Verify | Drift |
|-----------|----------|------|-------|--------|-------|
| 100-pve | [ ] | [ ] | [ ] | [ ] | [ ] |
| 102-traefik | [ ] | [ ] | [ ] | [ ] | [ ] |
| 104-grafana | [ ] | [ ] | [ ] | [ ] | [ ] |
| 105-elk | [ ] | [ ] | [ ] | [ ] | [ ] |
| 108-archon | [ ] | [ ] | [ ] | [ ] | [ ] |
| 215-synology | [ ] | [ ] | [ ] | [ ] | [ ] |
| 300-cloudflare | [ ] | [ ] | [ ] | [ ] | [ ] |
| 310-safetywallet | [ ] | [ ] | [ ] | [ ] | [ ] |
| 320-slack | [ ] | [ ] | [ ] | [ ] | [ ] |
| 400-gcp | [ ] | [ ] | [ ] | [ ] | [ ] |

---

## Rollback Procedure

**If critical issues are detected:**

1. **Immediate (0-15 minutes):**
   ```bash
   # Disable GitLab CI
   git mv .gitlab-ci.yml .gitlab-ci.yml.disabled
   git commit -m "emergency: disable GitLab CI"

   # Re-enable GitHub Actions
   git checkout backup/github-actions-YYYY-MM-DD -- .github/workflows/
   git commit -m "emergency: restore GitHub Actions"
   git push
   ```

2. **Short-term (15-60 minutes):**
   - Verify GitHub Actions runner is healthy
   - Trigger workflows manually to verify operation
   - Investigate GitLab CI issues

3. **Decision Point (60 minutes):**
   - If GitHub Actions stable: Continue rollback
   - If issues persist: Escalate and engage backup team

---

## Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Lead Engineer | | | |
| Infrastructure Owner | | | |
| Security Review | | | |
| Operations | | | |

---

**Notes:**
- Keep this checklist updated during migration
- Document any deviations from plan
- Save all command outputs for audit trail
