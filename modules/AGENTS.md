# AGENTS: modules - Shared Module Governance

## OVERVIEW
Parent scope for reusable Terraform modules. Child module AGENTS define behavior; this file defines shared module contract and boundaries.

## STRUCTURE
```text
modules/
├── proxmox/       # Proxmox provisioning, firewall, config rendering/deploy modules
├── shared/        # Provider-agnostic utility modules
├── cloudflare/    # Reusable Cloudflare tunnel module
└── elasticstack/  # Reusable ILM/index template modules
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Proxmox module family | `modules/proxmox/AGENTS.md` | Parent map for LXC/VM/rendering modules. |
| Shared utility modules | `modules/shared/AGENTS.md` | Provider-agnostic reusable modules. |
| Cloudflare tunnel module | `modules/cloudflare/AGENTS.md` | Reusable tunnel resource contract. |
| Elasticstack helper modules | `modules/elasticstack/AGENTS.md` | ILM policy and index template contracts. |
| Module test harnesses | `tests/AGENTS.md` | Shared test conventions for module scopes. |

## CONVENTIONS
- Keep module sources relative (`../modules/...`) from workspaces.
- Keep module interfaces explicit in `variables.tf` and `outputs.tf` with descriptions.
- Keep module contracts stable; evolve by additive variables before breaking changes.
- Keep provider-specific module families under their own provider directory once there is more than one module or a distinct lifecycle.
- Cloudflare currently has one reusable module (`tunnel/`), but it still gets its own child scope because the provider lifecycle differs from Proxmox/shared modules.

## ANTI-PATTERNS
- Do not hardcode environment-specific IPs or secrets in modules.
- Do not mix generated output files into module source-of-truth logic.
- Do not bypass module boundaries with direct resource duplication in workspaces.
