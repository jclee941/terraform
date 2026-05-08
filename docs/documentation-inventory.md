# Documentation Inventory

Source of truth for all documentation in the Terraform homelab repository.

**Last Updated:** 2026-05-07
**Total Markdown Files:** 100+
**Root Entry Point:** `README.md` (human-facing) and `AGENTS.md` (AI-facing)

---

## Root-Level Primary Docs

| Path | Type | Status | Owner Area | Action |
|------|------|--------|------------|--------|
| `AGENTS.md` | Project entry point | `active` | All | Keep current. Loads every session. |
| `README.md` | Project entry point | `active` | All | Human-facing root documentation. |
| `ARCHITECTURE.md` | System architecture | `active` | Infrastructure | Update when topology changes. |
| `CODE_STYLE.md` | Code conventions | `active` | All | Amend when conventions evolve. |
| `DEPENDENCY_MAP.md` | Module dependencies | `active` | Infrastructure | Update when workspace/module links change. |

## docs/ Operational Docs

| Path | Type | Status | Owner Area | Action |
|------|------|--------|------------|--------|
| `docs/backup-strategy.md` | Operational guide | `active` | Infrastructure | Update when backup tooling changes. |
| `docs/cloudflare-token-rotation.md` | Security runbook | `active` | Security | Update on rotation procedure changes. |
| `docs/module-release-process.md` | Release guide | `active` | Modules | Update when tag or release workflow changes. |
| `docs/proxmox-pxe-install.md` | Installation guide | `active` | Infrastructure | Update when PXE workflow changes. |
| `docs/secret-management.md` | Security guide | `active` | Security | Update when 1Password integration changes. |
| `docs/workspace-ordering.md` | Naming convention | `active` | Infrastructure | Update when new workspace tiers are added. |
| `docs/ALERTING-REFERENCE.md` | Monitoring reference | `active` | Operations | Update when alert rules or thresholds change. |
| `docs/infrastructure-modernization-master-plan.md` | Strategic plan | `archived` | Infrastructure | Plan is complete. Archived to `docs/archive/`. |

## docs/adr/ Architecture Decision Records

| Path | Type | Status | Owner Area | Action |
|------|------|--------|------------|--------|
| `docs/adr/001-monorepo-structure.md` | ADR | `historical` | Architecture | Immutable. Supersede with new ADR if needed. |
| `docs/adr/002-mcphub-single-entrypoint.md` | ADR | `historical` | Architecture | Immutable. |
| `docs/adr/003-cloudflare-tunnel-architecture.md` | ADR | `historical` | Architecture | Immutable. |
| `docs/adr/004-onepassword-vault-standardization.md` | ADR | `historical` | Architecture | Immutable. |
| `docs/adr/014-cloud-init-for-lxc.md` | ADR | `accepted` | Architecture | Immutable. Implementation complete. Append status, do not rewrite decision. |
| `docs/adr/README.md` | ADR index | `active` | Architecture | Maintain ADR status table and documented numbering gaps. |

**ADR Gaps:** Records 005 through 013 are absent and documented as intentional/unknown gaps in `docs/adr/README.md`. Do not fabricate placeholder ADRs.

## docs/runbooks/ Operational Runbooks

| Path | Type | Status | Owner Area | Action |
|------|------|--------|------------|--------|
| `docs/runbooks/backup-restore.md` | Incident response | `active` | Operations | Update after every restore drill. |
| `docs/runbooks/credential-rotation.md` | Security procedure | `active` | Security | Update when rotation targets change. |
| `docs/runbooks/disaster-recovery.md` | Incident response | `active` | Operations | Update after DR exercises. |
| `docs/runbooks/disk-full.md` | Troubleshooting | `active` | Operations | Update when alert thresholds change. |
| `runbooks/drift-detection.md` | Maintenance | `active` | Terraform | Update when scheduled drift workflow or workspace matrix changes. |
| `docs/runbooks/elk-index-migration.md` | Maintenance | `active` | ELK | Update when index patterns or ILM policies change. |
| `docs/runbooks/elk-integration-template.md` | Onboarding | `active` | ELK | Update when Filebeat or Logstash configs change. |
| `docs/runbooks/mcp-health-check.md` | Health check | `active` | MCPHub | Update when health endpoints change. |
| `docs/runbooks/monitoring-gaps.md` | Troubleshooting | `active` | Operations | Update when new services are added. |
| `docs/runbooks/network-issues.md` | Troubleshooting | `active` | Operations | Update when network topology changes. |
| `docs/runbooks/pve-filebeat-deployment.md` | Deployment | `active` | ELK | Update when Filebeat version or config changes. |
| `docs/runbooks/service-deployment.md` | Deployment | `active` | Operations | Update when CI/CD workflow changes. |
| `docs/runbooks/service-down.md` | Incident response | `active` | Operations | Update after post-mortems. |
| `docs/runbooks/state-locking.md` | Troubleshooting | `active` | Terraform | Update when backend or state setup changes. |
| `docs/runbooks/supabase-health-check.md` | Health check | `active` | Supabase | Update when Supabase version or endpoints change. |
| `docs/runbooks/terraform-state-rollback.md` | Incident response | `active` | Terraform | Update when state backup procedure changes. |
| `docs/runbooks/troubleshooting.md` | General guide | `active` | Operations | Update as new failure modes are discovered. |

## docs/design/ Design Specs

| Path | Type | Status | Owner Area | Action |
|------|------|--------|------------|--------|
| `docs/design/lxc-cloud-init-spec.md` | Design spec | `implemented` | Infrastructure | Keep in sync with module changes. |

## Workspace README Files

| Path | Type | Status | Owner Area | Action |
|------|------|--------|------------|--------|
| `80-jclee/README.md` | Service docs | `active` | Workstation | Hand-written. Keep current. |
| `100-pve/README.md` | Service docs | `generated-section-preserve` | PVE | Hand-written intro + terraform-docs section. Regenerate via `make docs`. |
| `100-pve/envs/prod/README.md` | Service docs | `generated-section-preserve` | PVE | terraform-docs generated. Regenerate via `make docs`. |
| `100-pve/pve-hacks/README.md` | Service docs | `removed` | PVE | Empty file. Deleted. |
| `101-runner/README.md` | Service docs | `active` | CI/CD | Hand-written. Keep current. |
| `102-traefik/README.md` | Service docs | `active` | Traefik | Hand-written. Keep current. |
| `102-traefik/terraform/README.md` | Service docs | `generated-section-preserve` | Traefik | terraform-docs generated. Regenerate via `make docs`. |
| `103-coredns/README.md` | Service docs | `active` | DNS | Hand-written. Keep current. |
| `105-elk/terraform/README.md` | Service docs | `generated-section-preserve` | ELK | terraform-docs generated. Regenerate via `make docs`. |
| `112-mcphub/README.md` | Service docs | `active` | MCPHub | Hand-written. Keep current. |
| `200-oc/README.md` | Service docs | `active` | OpenCode | Hand-written. Keep current. |
| `215-synology/README.md` | Service docs | `generated-section-preserve` | Storage | terraform-docs generated. Regenerate via `make docs`. |
| `220-youtube/README.md` | Service docs | `active` | YouTube | Hand-written. Keep current. |
| `300-cloudflare/README.md` | Service docs | `generated-section-preserve` | Cloudflare | terraform-docs generated. Regenerate via `make docs`. |
| `300-cloudflare/docker/cloudflared/README.md` | Service docs | `active` | Cloudflare | Hand-written. Keep current. |
| `310-safetywallet/README.md` | Service docs | `active` | SafetyWallet | Hand-written. Keep current. |

## Module README Files

| Path | Type | Status | Owner Area | Action |
|------|------|--------|------------|--------|
| `modules/proxmox/lxc/README.md` | Module docs | `generated-section-preserve` | Modules | Hand-written intro + terraform-docs section. Regenerate via `make docs`. |
| `modules/proxmox/vm/README.md` | Module docs | `generated-section-preserve` | Modules | Hand-written intro + terraform-docs section. Regenerate via `make docs`. |
| `modules/proxmox/lxc-config/README.md` | Module docs | `generated-section-preserve` | Modules | Hand-written intro + terraform-docs section. Regenerate via `make docs`. |
| `modules/proxmox/vm-config/README.md` | Module docs | `generated-section-preserve` | Modules | Hand-written intro + terraform-docs section. Regenerate via `make docs`. |
| `modules/proxmox/config-renderer/README.md` | Module docs | `generated-section-preserve` | Modules | Hand-written intro + terraform-docs section. Regenerate via `make docs`. |
| `modules/shared/onepassword-secrets/README.md` | Module docs | `generated-section-preserve` | Modules | Hand-written intro + terraform-docs section. Regenerate via `make docs`. |

## Test README Files

| Path | Type | Status | Owner Area | Action |
|------|------|--------|------------|--------|
| `tests/modules/proxmox/README.md` | Test docs | `generated-section-preserve` | Tests | terraform-docs generated. Regenerate via `make docs`. |
| `tests/modules/shared/README.md` | Test docs | `generated-section-preserve` | Tests | terraform-docs generated. Regenerate via `make docs`. |
| `tests/integration/README.md` | Test docs | `generated-section-preserve` | Tests | terraform-docs generated. Regenerate via `make docs`. |
| `tests/workspaces/pve/README.md` | Test docs | `generated-section-preserve` | Tests | terraform-docs generated. Regenerate via `make docs`. |
| `tests/workspaces/traefik/README.md` | Test docs | `generated-section-preserve` | Tests | terraform-docs generated. Regenerate via `make docs`. |
| `tests/workspaces/archon/README.md` | Test docs | `generated-section-preserve` | Tests | terraform-docs generated. Regenerate via `make docs`. |
| `tests/workspaces/elk/README.md` | Test docs | `generated-section-preserve` | Tests | terraform-docs generated. Regenerate via `make docs`. |
| `tests/workspaces/cloudflare/README.md` | Test docs | `generated-section-preserve` | Tests | terraform-docs generated. Regenerate via `make docs`. |

## Auto-Synced AGENTS.md Files

Approximately 72 `AGENTS.md` files are auto-synced from `qws941/.github`. These files appear in nearly every directory and subdirectory.

| Path Pattern | Count | Status | Action |
|--------------|-------|--------|--------|
| `*/AGENTS.md` (root) | 1 | `synced-do-not-edit` | Do not hand-edit. Update upstream in `qws941/.github`. |
| `1xx-*/AGENTS.md` | 8 | `synced-do-not-edit` | Do not hand-edit. |
| `1xx-*/config/AGENTS.md` | 5 | `synced-do-not-edit` | Do not hand-edit. |
| `1xx-*/templates/AGENTS.md` | 6 | `synced-do-not-edit` | Do not hand-edit. |
| `1xx-*/terraform/AGENTS.md` | 3 | `synced-do-not-edit` | Do not hand-edit. |
| `2xx-*/AGENTS.md` | 3 | `synced-do-not-edit` | Do not hand-edit. |
| `3xx-*/AGENTS.md` | 3 | `synced-do-not-edit` | Do not hand-edit. |
| `300-cloudflare/workers/*/AGENTS.md` | 2 | `synced-do-not-edit` | Do not hand-edit. |
| `300-cloudflare/scripts/AGENTS.md` | 1 | `synced-do-not-edit` | Do not hand-edit. |
| `400-gcp/AGENTS.md` | 1 | `synced-do-not-edit` | Do not hand-edit. |
| `80-jclee/AGENTS.md` | 1 | `synced-do-not-edit` | Do not hand-edit. |
| `modules/AGENTS.md` | 1 | `synced-do-not-edit` | Do not hand-edit. |
| `modules/proxmox/AGENTS.md` | 1 | `synced-do-not-edit` | Do not hand-edit. |
| `modules/proxmox/*/AGENTS.md` | 5 | `synced-do-not-edit` | Do not hand-edit. |
| `modules/proxmox/*/templates/AGENTS.md` | 2 | `synced-do-not-edit` | Do not hand-edit. |
| `modules/proxmox/*/configs/AGENTS.md` | 2 | `synced-do-not-edit` | Do not hand-edit. |
| `modules/shared/AGENTS.md` | 1 | `synced-do-not-edit` | Do not hand-edit. |
| `modules/shared/onepassword-secrets/AGENTS.md` | 1 | `synced-do-not-edit` | Do not hand-edit. |
| `scripts/AGENTS.md` | 1 | `synced-do-not-edit` | Do not hand-edit. |
| `scripts/n8n-workflows/AGENTS.md` | 1 | `synced-do-not-edit` | Do not hand-edit. |
| `tests/AGENTS.md` | 1 | `synced-do-not-edit` | Do not hand-edit. |
| `tests/*/AGENTS.md` | 2 | `synced-do-not-edit` | Do not hand-edit. |
| `tests/workspaces/AGENTS.md` | 1 | `synced-do-not-edit` | Do not hand-edit. |
| `tests/workspaces/*/AGENTS.md` | 7 | `synced-do-not-edit` | Do not hand-edit. |
| `docs/AGENTS.md` | 1 | `synced-do-not-edit` | Do not hand-edit. |
| `docs/adr/AGENTS.md` | 1 | `synced-do-not-edit` | Do not hand-edit. |
| `docs/runbooks/AGENTS.md` | 1 | `synced-do-not-edit` | Do not hand-edit. |
| `112-mcphub/op-mcp-server/AGENTS.md` | 1 | `synced-do-not-edit` | Do not hand-edit. |
| `101-runner/scripts/AGENTS.md` | 1 | `synced-do-not-edit` | Do not hand-edit. |

**Total:** ~72 files. All are managed by the `qws941/.github` sync pipeline. Hand-edits will be overwritten on the next sync.

## Archive Candidates

| Path | Type | Status | Owner Area | Action |
|------|------|--------|------------|--------|
| `docs/infrastructure-modernization-master-plan.md` | Strategic plan | `archived` | Infrastructure | Moved to `docs/archive/infrastructure-modernization-master-plan-2026-03-31.md`. |
| `modules/CHANGELOG.md` | Release notes | `removed` | Modules | Deleted. Use Git tag messages or GitHub releases instead. |

## Other Documentation

| Path | Type | Status | Owner Area | Action |
|------|------|--------|------------|--------|
| `215-synology/syslog-config.md` | Service config | `active` | Storage | Hand-written. Keep current. |
| `300-cloudflare/docs/requirements.md` | Requirements | `active` | Cloudflare | Hand-written. Keep current. |
| `scripts/n8n-workflows/N8N-AUDIT.md` | Audit log | `active` | n8n | Hand-written. Append new audit entries. |

---

## Documentation Rules

### Auto-Generated Content

Several README files contain sections that are auto-generated by `terraform-docs`. These sections sit between `<!-- BEGIN_TF_DOCS -->` and `<!-- END_TF_DOCS -->` markers.

**Files with auto-generated sections:**
- `100-pve/README.md`
- `100-pve/envs/prod/README.md`
- `102-traefik/terraform/README.md`
- `105-elk/terraform/README.md`
- `215-synology/README.md`
- `300-cloudflare/README.md`
- All module READMEs under `modules/proxmox/*/` and `modules/shared/onepassword-secrets/`
- All test READMEs under `tests/modules/*/`, `tests/integration/`, and `tests/workspaces/*/`

**How to update:** Edit the Terraform source (variables, outputs, resources), then run `make docs` to regenerate the marked sections. Do not edit the content between the terraform-docs markers by hand.

### Auto-Synced Files

All `AGENTS.md` files outside the repository root are auto-synced from `qws941/.github`. The root `AGENTS.md` is the local source of truth for this repository, but subdirectory copies are maintained by a sync pipeline.

**How to update:** Change the upstream template in `qws941/.github`. The next sync push will overwrite all subdirectory `AGENTS.md` files. If you need a repo-specific `AGENTS.md` to persist, update `.github/sync.yml` to exclude that path from syncing.

### Do Not Hand-Edit

- `100-pve/configs/` and any `configs/` directory under modules: These are Terraform-rendered outputs. Regenerate via `terraform apply` in the `100-pve` workspace.
- `AGENTS.md` files in subdirectories: These are synced from `qws941/.github`.
- Content between `<!-- BEGIN_TF_DOCS -->` and `<!-- END_TF_DOCS -->` markers in README files.

### Diagrams

- Use Mermaid for architecture and dependency diagrams. ASCII diagrams are deprecated.
- See `CODE_STYLE.md` for full documentation conventions.


### How to Update Docs

1. **Hand-written docs:** Edit the source `.md` file directly. Commit with a conventional commit message.
2. **Terraform-docs READMEs:** Edit the `.tf` source files, then run `make docs` to regenerate the marked sections.
3. **Rendered configs:** Edit the `.tftpl` template in the service workspace, then run `terraform apply` in `100-pve`.
4. **AGENTS.md:** Edit the upstream in `qws941/.github`, or update the root `AGENTS.md` for repo-specific guidance.
