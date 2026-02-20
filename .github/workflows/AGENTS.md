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

## COMMANDS
```bash
make plan SVC=pve
make plan SVC=cloudflare
make apply SVC=pve
```
