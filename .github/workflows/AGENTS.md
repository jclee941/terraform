# AGENTS: .github/workflows — Workflow Definitions

## OVERVIEW
Workflow implementation layer for CI/CD. Keep this scope focused on trigger paths, reusable workflow contracts, and service plan/apply pairing.

## STRUCTURE
```text
.github/workflows/
├── terraform-plan.yml / terraform-apply.yml     # Core 100-pve workflows
├── _terraform-plan.yml / _terraform-apply.yml   # Reusable workflow contracts
├── {svc}-plan.yml / {svc}-apply.yml             # Service workflow pairs
├── terraform-drift.yml                           # Matrix drift checks
├── mcp-health-check.yml                          # MCP port health + issue dedup
└── auto-merge.yml + security/automation flows    # Risk-tier + governance
```

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Update reusable behavior | `_terraform-plan.yml`, `_terraform-apply.yml` | Input/secret contract for service workflows. |
| Adjust core 100-pve flow | `terraform-plan.yml`, `terraform-apply.yml` | Core workspace lifecycle only. |
| Add service plan/apply | `{svc}-plan.yml`, `{svc}-apply.yml` | Keep naming and pairing symmetric. |
| Drift matrix changes | `terraform-drift.yml` | Maintain workspace matrix + issue dedup behavior. |
| Merge policy | `auto-merge.yml` | Risk tier routing (critical/medium/low). |

## CONVENTIONS
- Keep service workflows thin wrappers around `_terraform-*` reusable workflows.
- Preserve plan/apply parity: same service name, same working directory, matching migration flags.
- Keep Terraform workflows on `self-hosted` runner; non-TF automation can stay on `ubuntu-latest`.
- Pin `uses:` actions to commit SHAs and keep secret wiring in `secrets: inherit` or explicit env mapping.
- When changing trigger paths, verify they still match owning stack directories.

## ANTI-PATTERNS
- Do not add standalone duplicated logic to `{svc}-plan.yml` when `_terraform-plan.yml` can own it.
- Do not break plan/apply pair symmetry for a service.
- Do not leak secret values through echo/printf in workflow steps.
- Do not move Terraform jobs off `self-hosted` for homelab-dependent operations.
- Do not change risk-tier rules without updating docs in `.github/AGENTS.md`.

## NOTES

- `terraform-plan.yml` / `terraform-apply.yml` (100-pve) are **intentionally standalone** — not wrappers around `_terraform-*` reusable workflows. Reasons:
  - Proxmox-specific secrets (`PROXMOX_ENDPOINT`, `PROXMOX_API_TOKEN`, `PROXMOX_INSECURE`) are absent from the reusable template's secret contract.
  - Apply pipeline includes a unique Proxmox resource import script (7 LXC + 1 VM) with show→import→skip-if-managed logic that has no equivalent in the reusable template.
  - Plan workflow uploads `tfplan` artifact (7-day retention) for plan-then-apply-from-file flow, vs reusable's `-auto-approve`.
  - Path triggers span `100-pve/**`, `modules/**`, and 13 service-template directories across all services.
- All 7 Terraform workspaces use `backend "local" {}`. State locking is enforced via:
  - GHA `concurrency` groups with `cancel-in-progress: false` on all apply workflows — prevents parallel applies to same workspace.
  - Local `make apply` is disabled (`exit 1`) — all applies route through CI.
  - `.tfstate` files tracked in git for CI reliability (single-writer model via concurrency).
- Drift detection (`terraform-drift.yml`) runs on push to master AND weekday schedule (Mon-Fri 00:00 UTC). Matrix covers all 7 workspaces with `fail-fast: false`.

## COMMANDS
```bash
make plan SVC=pve
make plan SVC=cloudflare
# make apply is DISABLED locally — all applies go through CI/CD workflows
# Trigger apply by merging PR to master (terraform-apply.yml / {svc}-apply.yml)
```
