> **Status:** Archived
> **Archived:** 2026-05-07
> **Reason:** This planning artifact is superseded by the current repository state and active architecture documentation. Keep for historical context only.

# Infrastructure Modernization Master Plan

**Homelab Terraform Infrastructure** | Version 1.0
**Created:** 2026-03-31 | **Review Cycle:** Weekly
**Status:** Planning Complete → Execution Ready

---

## Executive Summary

This master plan orchestrates a **4-wave, 14-week modernization program** to evolve the homelab infrastructure from maturity **6.0/10 to 8.6/10**. The program is structured to minimize risk while maximizing parallel execution:

1. **Wave 1 (Weeks 1-3):** Stabilize and standardize - remove operational debt
2. **Wave 2 (Week 4):** Backend foundation - isolated GCS state migration
3. **Wave 3 (Weeks 5-7):** Platform extraction and HA - unlock downstream automation
4. **Wave 4 (Weeks 8-14):** Higher-order automation - drift remediation, GitOps, self-healing

**Critical Path:** `#4 GCS Backend → #11 Host Inventory → #15 Workspace Pipelines` (64h raw, ~104h buffered)

**Resource Requirements:** 2 engineers + 0.2-0.3 ops support | **Total Effort:** ~360 hours

---

## Current State Snapshot

| Dimension | Score | Wave 4 Target |
|-----------|-------|---------------|
| Coverage | 6/10 | 9/10 |
| Security | 4/10 | 8/10 |
| Testing | 5/10 | 8/10 |
| Recovery/Rollback | 3/10 | 9/10 |
| **Overall** | **6.0/10** | **8.6/10** |

**Active Pain Points:**
- Hardcoded IPs bypassing SSoT
- Local state backend (no locking, SPOF)
- Local-only backups
- Single Proxmox node
- No module versioning
- Limited test coverage (5/10 workspaces)
- No security scanning in CI

---

## Parallel Execution Waves

### Wave 1: Stabilize and Standardize (Weeks 1-3)
**Theme:** Remove operational debt, establish hygiene

| ID | Initiative | Effort | Risk | Owner |
|----|------------|--------|------|-------|
| #1 | Fix hardcoded IPs in production-verification.go | 4h | Low | Platform |
| #3 | Enable blocking verification stage | 1h | Low | Platform |
| #5 | Implement offsite backup replication | 12h | Medium | Infra |
| #6 | Add security scanning to CI | 4h | Low | Platform |
| #7 | Standardize workspace directory structure | 3h | Low | Platform |
| #8 | Expand test coverage to all workspaces | 8h | Medium | Platform |
| #10 | Version modules with Git tags | 12h | Medium | Infra |
| #13 | Centralize template registry | 12h | Medium | Platform |
| #14 | Add automated rollback mechanism | 16h | Medium | Infra |

**Parallel Capacity:** 9 tasks, max 6 concurrent (team capacity)
**Total Effort:** 72 hours
**Dependencies:** None - all can run in parallel

#### Wave 1 Success Gate (End of Week 3)
- [ ] `production-verification.go` reads host/IP data from SSoT path only
- [ ] CI blocks merges on verification failure
- [ ] Security scan runs on every MR and fails pipeline on threshold
- [ ] Test harness exists for all active workspaces
- [ ] Offsite backup has one successful restore drill
- [ ] Rollback path documented and tested for one workspace

---

### Wave 2: Backend Foundation (Week 4)
**Theme:** Isolated state backend migration - high risk, focused attention

| ID | Initiative | Effort | Risk | Owner |
|----|------------|--------|------|-------|
| #4 | Migrate to GCS remote state backend | 16h raw / **32h buffered** | **HIGH** | Infra Lead |

**Why Isolated:** Changes state semantics, requires focused attention

#### Week 4 Schedule
| Day | Activity |
|-----|----------|
| Mon | Rehearse migration on 300-cloudflare (canary) |
| Tue | Verify locking, plan=no-op, freeze concurrent applies |
| Wed | Migrate Tier 1 workspaces (102, 104, 105, 108) |
| Thu | Migrate independent workspaces (300, 310, 320, 400) |
| Fri | Migrate Tier 0 (100-pve) with full team on-call |

#### Wave 2 Success Gate (End of Week 4)
- [ ] All active workspaces read/write state from GCS
- [ ] Locking verified with concurrent pipeline attempts
- [ ] Last-known-good local state archived and restore-tested
- [ ] No workspace shows drift introduced by migration

#### Rollback Procedure
```bash
# 1. Freeze merges and applies
# 2. Export and checksum every current local state file
# 3. If validation fails, point backend config back to local
# 4. Restore last verified .tfstate
# 5. Re-run plan before reopening pipelines
```

---

### Wave 3: Platform Extraction and HA (Weeks 5-7)
**Theme:** Use centralized state to unlock inventory extraction and HA

| ID | Initiative | Effort | Risk | Owner | Dependencies |
|----|------------|--------|------|-------|--------------|
| #9 | Automated state backup in CI/CD | 4h | Low | Platform | #4 |
| #11 | Extract host inventory to module | 16h | **Medium-High** | Infra | #4 |
| #16 | Multi-node Proxmox HA | 40h raw / **60h buffered** | **HIGH** | Infra | None |

**Parallel Capacity:** 3 tasks, #9 and #11 sequential, #16 parallel
**Total Effort:** 80 hours (buffered)

#### Week 5-7 Schedule
| Week | Focus |
|------|-------|
| 5 | Start #9 (auto backup), Start #11 (inventory design), #16 prep (procurement/network) |
| 6 | Finish #9, Continue #11 (implementation), #16 node setup |
| 7 | Finish #11, #16 failover validation and runbooks |

#### Wave 3 Success Gate (End of Week 7)
- [ ] State backups run automatically from CI, retained offsite
- [ ] At least one workspace consumes host inventory module end-to-end
- [ ] Proxmox failover test passes for non-critical workload
- [ ] HA runbook and rollback procedure complete

---

### Wave 4: Higher-Order Automation (Weeks 8-14)
**Theme:** Consumers of new backend, inventory model, and HA foundation

| ID | Initiative | Effort | Risk | Owner | Dependencies |
|----|------------|--------|------|-------|--------------|
| #12 | Automated drift remediation | 24h | **HIGH** | Platform | #11 |
| #15 | Workspace-specific pipelines | 32h | High | Platform | #11 |
| #17 | 1Password Connect HA | 16h | Medium | Infra | #16 |
| #18 | Self-healing infrastructure | 80h | **HIGH** | Infra | #11, #16 |
| #19 | GitOps-style deployments | 32h | Medium | Platform | #15 |

**Parallel Capacity:** 5 tasks, phased execution
**Total Effort:** 184 hours

#### Wave 4 Execution Phases
| Weeks | Focus |
|-------|-------|
| 8-9 | Start #12 (detect-only mode), Start #15, Start #17 |
| 10 | Finish #12, Finish #17, Continue #15 |
| 11 | Finish #15, Start #19 pilot |
| 12-14 | #18 self-healing pilot (constrained to non-critical), Finish #19 |

#### Wave 4 Success Gate (End of Week 14)
- [ ] Drift remediation in detect/report mode, moving to manual-approval
- [ ] Workspace-specific pipelines deploy only changed workspaces
- [ ] 1Password Connect survives single-node failure
- [ ] Self-healing piloted on non-critical services

---

## Critical Path Analysis

### True Longest Dependency Chain
```
#4 GCS Backend (16h) → #11 Host Inventory (16h) → #15 Workspace Pipelines (32h)
```

| Calculation | Hours |
|-------------|-------|
| Raw duration | 64h |
| Buffered (risk-adjusted) | ~104h |
| **Program minimum** | **~13 weeks** (with parallel work) |

### Secondary Chain
```
#4 → #11 → #12 Drift Remediation
```
- Raw: 56h
- Buffered: ~92h

### Independent Chain (Parallelizable)
```
#16 Proxmox HA → #17 Connect HA
```
- Raw: 56h
- Buffered: ~84h

**Key Insight:** Backend migration is the main unlock, but pipeline specialization (#15) is the actual longest downstream consumer.

---

## Dependency Graph

```
Wave 1 (Independent)
├─ #1 Fix hardcoded IPs
├─ #3 Enable blocking verification
├─ #5 Offsite backup
├─ #6 Security scanning
├─ #7 Workspace structure
├─ #8 Test coverage
├─ #10 Module versioning
├─ #13 Template registry
└─ #14 Rollback mechanism

Wave 2 (Isolated)
└─ #4 GCS Backend
    ├─→ #9 Auto state backup
    ├─→ #11 Host inventory
    │   ├─→ #12 Drift remediation
    │   ├─→ #15 Workspace pipelines
    │   └─→ #18 Self-healing
    └─ (parallel) #16 Proxmox HA
        └─→ #17 Connect HA

Wave 4 (Consumers)
├─ #12 Drift remediation
├─ #15 Workspace pipelines
├─ #17 Connect HA
├─ #18 Self-healing
└─ #19 GitOps deployments
```

---

## Week-by-Week Timeline

### Week 1: Wave 1 Kickoff
| Day | Tasks |
|-----|-------|
| Mon | Start #1, #3, #6, #7 |
| Tue | Continue Wave 1 tasks |
| Wed | Start #8 baseline, Define #14 rollback standard |
| Thu | Continue Wave 1 |
| Fri | Week 1 checkpoint, Demo #1, #3, #6, #7 |

### Week 2: Wave 1 Continuation
| Day | Tasks |
|-----|-------|
| Mon | Finish #1, #3, #6, #7 |
| Tue | Start/finish #10 |
| Wed | Start #5 (offsite backup) |
| Thu | Start #13 (template registry) |
| Fri | Week 2 checkpoint |

### Week 3: Wave 1 Completion
| Day | Tasks |
|-----|-------|
| Mon | Finish #5, #10, #13 |
| Tue | Finish #14 |
| Wed | **Wave 1 Success Gate Review** |
| Thu | Prepare #4: backend design, IAM, rehearsal plan |
| Fri | Freeze plan for Week 4 migration |

### Week 4: Wave 2 - GCS Migration
| Day | Tasks |
|-----|-------|
| Mon | Rehearse on 300-cloudflare (canary) |
| Tue | Verify locking, plan=no-op, freeze applies |
| Wed | Migrate Tier 1 workspaces |
| Thu | Migrate independent workspaces |
| Fri | Migrate Tier 0 (100-pve) - full team on-call |

### Week 5: Wave 3 Start
| Day | Tasks |
|-----|-------|
| Mon | Start #9 (auto backup) |
| Tue | Start #11 (inventory design) |
| Wed | #16 prep (procurement, network) |
| Thu | Continue #9, #11, #16 |
| Fri | Week 5 checkpoint |

### Week 6: Wave 3 Mid
| Day | Tasks |
|-----|-------|
| Mon | Finish #9 |
| Tue | Continue #11 implementation |
| Wed | #16 node setup |
| Thu | Continue #11, #16 |
| Fri | Week 6 checkpoint |

### Week 7: Wave 3 Completion
| Day | Tasks |
|-----|-------|
| Mon | Finish #11 |
| Tue | #16 failover validation |
| Wed | HA runbooks |
| Thu | **Wave 3 Success Gate Review** |
| Fri | Plan Wave 4 kickoff |

### Week 8: Wave 4 Kickoff
| Day | Tasks |
|-----|-------|
| Mon | Start #12 (detect-only) |
| Tue | Start #15 |
| Wed | Start #17 |
| Thu | Continue Wave 4 |
| Fri | Week 8 checkpoint |

### Week 9: Wave 4 Mid
| Day | Tasks |
|-----|-------|
| Mon | Continue #12, #15, #17 |
| Tue | Continue Wave 4 |
| Wed | Continue Wave 4 |
| Thu | Continue Wave 4 |
| Fri | Week 9 checkpoint |

### Week 10: Wave 4 Progress
| Day | Tasks |
|-----|-------|
| Mon | Finish #12 |
| Tue | Finish #17 |
| Wed | Continue #15 |
| Thu | Continue #15 |
| Fri | Week 10 checkpoint |

### Week 11: Wave 4 Continuation
| Day | Tasks |
|-----|-------|
| Mon | Finish #15 |
| Tue | Start #19 pilot |
| Wed | Continue #19 |
| Thu | Plan #18 pilot scope |
| Fri | Week 11 checkpoint |

### Week 12: Wave 4 - Self-Healing Pilot
| Day | Tasks |
|-----|-------|
| Mon | Start #18 pilot (non-critical only) |
| Tue | #18 pilot with cooldowns and limits |
| Wed | Monitor #18, continue #19 |
| Thu | #18 review, adjust scope |
| Fri | Week 12 checkpoint |

### Week 13: Wave 4 Completion
| Day | Tasks |
|-----|-------|
| Mon | Continue #18, #19 |
| Tue | Continue Wave 4 |
| Wed | #18 pilot review |
| Thu | Finish #19 |
| Fri | Week 13 checkpoint |

### Week 14: Program Completion
| Day | Tasks |
|-----|-------|
| Mon | Finalize #18 pilot documentation |
| Tue | **Wave 4 Success Gate Review** |
| Wed | Program retrospective |
| Thu | Handoff to operations |
| Fri | **Program Complete** |

---

## Risk Matrix

| Initiative | Risk | Impact | Mitigation | Rollback Trigger |
|------------|------|--------|------------|------------------|
| **#4 GCS Backend** | **HIGH** | Blocks all workspaces | Rehearse on canary, snapshot all states, freeze applies, verify locking | State read mismatch, failed lock, plan drift from backend change |
| **#11 Host Inventory** | **Medium-High** | Breaks cross-workspace refs | Adapter outputs first, incremental migration, keep old interface | Consumer needs output shape changes during cutover |
| **#12 Drift Remediation** | **HIGH** | Can amplify bad plans | Start detect-only, then ticket/manual mode, only later auto-apply for safe classes | False positive remediation, plan touching protected resources |
| **#16 Proxmox HA** | **HIGH** | Node/storage/network assumptions | Non-critical workloads first, validate quorum/storage/network, controlled failover test | Failed failover, quorum instability, storage replication lag |
| **#18 Self-Healing** | **HIGH** | Automation feedback loops | Stateless services first, cooldowns, action limits, log every action | Repeated oscillation, unintended restarts, unsafe remediation scope |

---

## Resource Requirements

### Team
| Role | Allocation | Weeks | Responsibilities |
|------|------------|-------|------------------|
| **Infra Lead** | 0.8 FTE | 1-14 | State migration, inventory model, rollout gates, HA |
| **Platform Engineer** | 1.0 FTE | 1-14 | CI, tests, security scanning, pipelines, GitOps |
| **Ops/Reviewer** | 0.2-0.3 FTE | 4-10 | Migration windows, backup drills, HA failover testing |

### Infrastructure
| Resource | Purpose | When |
|----------|---------|------|
| GCS bucket + IAM | Remote state backend | Week 4 |
| Offsite backup target | Backup replication | Week 2-3 |
| Additional Proxmox node(s) | HA cluster | Week 5-7 |
| Shared storage/network | HA infrastructure | Week 5-7 |
| CI runner capacity | Expanded tests, security scans | Week 1 |

### Budget Estimate
| Item | Cost |
|------|------|
| GCS storage (1 year) | ~$50 |
| Backblaze B2 (1 year) | ~$100 |
| Additional Proxmox node | Hardware cost |
| CI runner time | Existing infrastructure |

---

## Success Metrics

### KPIs by Wave

| Wave | KPI | Target |
|------|-----|--------|
| 1 | CI pipeline duration | 45min → 35min |
| 1 | Security scan pass rate | N/A → 90% |
| 1 | Test coverage | 28% → 60% |
| 2 | State backend | 0% → 100% GCS |
| 2 | Lock contention incidents | 0 |
| 3 | Automated backup coverage | 0% → 100% |
| 3 | HA failover test | Pass |
| 4 | Drift detection → remediation latency | 24h → 1h |
| 4 | Pipeline duration (changed workspaces only) | 35min → 15min |
| 4 | Deployment frequency | 2-3/week → Daily |

### Maturity Score Progression
| Phase | Score |
|-------|-------|
| Baseline | 6.0/10 |
| Wave 1 Complete | 6.8/10 |
| Wave 2 Complete | 7.2/10 |
| Wave 3 Complete | 7.8/10 |
| **Program Complete** | **8.6/10** |

---

## Rollback Procedures

### #4 GCS Backend Migration Rollback
```bash
# Emergency rollback procedure

# 1. Freeze all merges and applies immediately
# 2. Identify last known good local state
gsutil ls gs://tfstate-homelab-backups/*

# 3. For each affected workspace:
cd {workspace}

# 4. Update backend configuration
# Edit versions.tf: backend "local" {}

# 5. Restore local state
cp /backup/{workspace}-pre-migration.tfstate terraform.tfstate

# 6. Re-initialize
terraform init -migrate-state

# 7. Verify
terraform plan  # Should show no changes

# 8. Reopen pipelines once all workspaces verified
```

### #16 Proxmox HA Rollback
```bash
# Emergency HA rollback

# 1. Identify unstable node/resource
# 2. Disable HA for affected resources
ha-manager set vm:{vmid} --state disabled

# 3. Pin guests back to original node
qm set {vmid} --node pve3

# 4. Revert cluster resource assignments
# 5. Document incident for post-mortem
```

---

## Communication Plan

| Stakeholder | Communication | Frequency |
|-------------|--------------|-----------|
| Infra Team | Daily standup | Daily |
| Infra Lead + Platform Eng | 1:1 sync | Weekly |
| Full Team | Demo/Review | Per wave |
| Operations | Handoff docs | Wave 4 end |

### Demo Schedule
- **Week 3:** Wave 1 demo (IP fix, security scan, test coverage)
- **Week 4:** Wave 2 demo (GCS migration, locking verification)
- **Week 7:** Wave 3 demo (inventory module, HA failover)
- **Week 14:** Program completion demo (drift remediation, GitOps)

---

## Appendix A: Task Reference

| ID | Initiative | Priority | Effort | Wave | Dependencies |
|----|------------|----------|--------|------|--------------|
| #1 | Fix hardcoded IPs | P0 | S (4h) | 1 | None |
| #2 | Create drift-detection runbook | P0 | S (2h) | N/A | ✅ DONE |
| #3 | Enable blocking verification | P0 | S (1h) | 1 | None |
| #4 | GCS remote state | P0 | M (16h) | 2 | None |
| #5 | Offsite backup replication | P0 | M (12h) | 1 | None |
| #6 | Security scanning | P1 | S (4h) | 1 | None |
| #7 | Workspace structure | P1 | S (3h) | 1 | None |
| #8 | Test coverage | P1 | M (8h) | 1 | None |
| #9 | Auto state backup | P1 | S (4h) | 3 | #4 |
| #10 | Module versioning | P1 | M (12h) | 1 | None |
| #11 | Host inventory module | P1 | M (16h) | 3 | #4 |
| #12 | Drift remediation | P2 | L (24h) | 4 | #11 |
| #13 | Template registry | P2 | M (12h) | 1 | None |
| #14 | Rollback mechanism | P2 | M (16h) | 1 | None |
| #15 | Workspace pipelines | P2 | L (32h) | 4 | #11 |
| #16 | Proxmox HA | P2 | L (40h) | 3 | None |
| #17 | Connect HA | P3 | M (16h) | 4 | #16 |
| #18 | Self-healing | P3 | XL (80h) | 4 | #11, #16 |
| #19 | GitOps deployments | P3 | L (32h) | 4 | #15 |

---

## Appendix B: Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-31 | Wave 2 isolated for GCS migration | High risk requires focused attention, no parallel high-risk work |
| 2026-03-31 | #16 Proxmox HA in Wave 3 (not 2) | Can run parallel with #11, but after Wave 1 stabilization |
| 2026-03-31 | #18 Self-healing constrained to pilot | Full rollout too risky without extended observation |
| 2026-03-31 | 14-week timeline with 2 engineers | Critical path + risk buffers + parallel optimization |

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-31 | Infrastructure Team | Initial master plan |

**Next Review:** Weekly (Mondays)
**Change Process:** Update with team approval, version bump
**Distribution:** Infrastructure Team, Operations

---

**END OF MASTER PLAN**
