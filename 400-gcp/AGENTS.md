# AGENTS: 400-gcp — Google Cloud Platform Placeholder

> **Status**: Placeholder only
> **Tier**: Independent cloud workspace
> **Apply Order**: Independent; no dependency on Proxmox workspaces

## OVERVIEW
Reserved directory for a future GCP Terraform workspace. No GCP Terraform root exists here yet; current repo support is limited to routing metadata and placeholder tests.

## STRUCTURE
```
400-gcp/
└── AGENTS.md            # Current workspace guidance
```

## CURRENT SURFACE
| Component | Location | Status |
|-----------|----------|--------|
| Make alias | `Makefile` → `ALIAS_gcp := 400-gcp` | Prepared route only. |
| Tests | `tests/workspaces/gcp/` | Placeholder Terraform test workspace. |
| Secrets module | `modules/shared/onepassword-secrets/` | Has GCP enablement inputs for future use. |
| Terraform root | `400-gcp/*.tf` | Not present. |
| CI workflow | `.github/workflows/` | No dedicated GCP deployment workflow. |

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Add first GCP resources | `400-gcp/` | Create real Terraform files only from a concrete requirement. |
| Test placeholder behavior | `tests/workspaces/gcp/` | Keep tests mocked; no live GCP calls. |
| Secret lookup pattern | `modules/shared/onepassword-secrets/` | Reuse existing 1Password module contract. |
| Make routing | `Makefile` | Check service alias before adding commands. |

## CONVENTIONS
- Use a local backend unless a project decision introduces remote state.
- Keep GCP credentials in 1Password or CI secrets, never tfvars.
- Keep provider setup explicit: project ID, region, billing assumptions, and APIs.
- Add tests with the first real Terraform resources; placeholder tests should stay minimal.
- Document any cross-cloud dependency in the root AGENTS file when it becomes real.

## ANTI-PATTERNS
- Do not invent intended GCP products before requirements exist.
- Do not use default GCP project or ambient user credentials in committed config.
- Do not wire live GCP APIs into default tests.
- Do not copy Cloudflare patterns without checking GCP-specific provider behavior.

## COMMANDS
```bash
make validate SVC=gcp
make test-workspace SVC=gcp
terraform -chdir=tests/workspaces/gcp test
```

## NOTES
- This file is intentionally about current repo state, not a roadmap.
- When real Terraform files are added, replace this placeholder with resource-specific guidance.
