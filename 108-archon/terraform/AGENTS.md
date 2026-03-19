# AGENTS: 108-archon/terraform

## OVERVIEW
Nested Archon provider workspace. Today it is a remote-state shim for Archon host discovery; future Archon-specific provider resources should land here without mixing runtime template guidance into the service parent.

## STRUCTURE
```text
108-archon/terraform/
├── main.tf      # Remote-state host map local
├── versions.tf  # Local backend + infra remote-state contract
├── outputs.tf   # Exported host-inventory loaded signal
└── README.md    # terraform-docs output
```

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Infra remote-state contract | `versions.tf` | Reads `../../100-pve/terraform.tfstate` with empty defaults for CI. |
| Host inventory mapping | `main.tf` | Builds `local.hosts` from `host_inventory`. |
| Downstream contract output | `outputs.tf` | Exports `host_inventory_loaded` for smoke-check consumers and tests. |
| Workspace tests | `../../tests/workspaces/archon/archon_test.tftest.hcl` | Verifies canonical remote-state shape and empty fallback behavior. |

## CONVENTIONS
- Keep this workspace as the provider-facing Archon boundary; runtime templates and compose/env wiring stay in `../templates/` and the service parent.
- Keep host metadata sourced from `100-pve` remote state; empty defaults are intentional for CI planning.
- Treat `host_inventory_loaded` as a smoke-check output, not a substitute for richer host modeling elsewhere.
- Local apply stays disabled; use `make plan SVC=archon` or targeted `terraform test` for local review only.

## ANTI-PATTERNS
- Do not hardcode Archon host metadata or duplicate `100-pve` inventory here.
- Do not move LXC lifecycle, Docker Compose rendering, or source-manifest automation into this workspace.
- Do not add service-level troubleshooting prose here; keep that in `../AGENTS.md`.

## COMMANDS
```bash
make plan SVC=archon
make validate SVC=archon
cd tests/workspaces/archon && terraform init -backend=false && terraform test -filter=archon_test.tftest.hcl
```
