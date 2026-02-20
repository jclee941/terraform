# AGENTS: modules - Shared Module Governance

## OVERVIEW
Parent scope for reusable Terraform modules. Child module AGENTS define behavior; this file defines shared module contract and boundaries.

## STRUCTURE
```text
modules/
|- proxmox/   # Infrastructure provisioning + config rendering modules
`- shared/    # Provider-agnostic utility modules
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Proxmox module family | `modules/proxmox/AGENTS.md` | Parent map for LXC/VM/rendering modules. |
| Shared utility modules | `modules/shared/AGENTS.md` | Provider-agnostic reusable modules. |
| Module test harnesses | `tests/AGENTS.md` | Shared test conventions for module scopes. |

## CONVENTIONS
- Keep module sources relative (`../modules/...`) from workspaces.
- Keep module interfaces explicit in `variables.tf` and `outputs.tf` with descriptions.
- Keep module contracts stable; evolve by additive variables before breaking changes.
- Keep `BUILD.bazel` and `OWNERS` in each module subtree.

## ANTI-PATTERNS
- Do not hardcode environment-specific IPs or secrets in modules.
- Do not mix generated output files into module source-of-truth logic.
- Do not bypass module boundaries with direct resource duplication in workspaces.
