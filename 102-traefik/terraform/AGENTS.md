# AGENTS: 102-traefik/terraform

## OVERVIEW
Nested Traefik provider workspace. Today it is a remote-state shim that exposes Traefik host metadata from `100-pve`; future direct Traefik-provider resources belong here rather than in the service parent.

## STRUCTURE
```text
102-traefik/terraform/
├── main.tf      # Remote-state host map local
├── versions.tf  # Local backend + infra remote-state contract
├── outputs.tf   # Exported container IP and VMID
└── README.md    # terraform-docs output
```

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Infra remote-state contract | `versions.tf` | Reads `../../100-pve/terraform.tfstate` with empty defaults for CI. |
| Host inventory mapping | `main.tf` | Builds `local.hosts` from `host_inventory`. |
| Downstream host outputs | `outputs.tf` | Exports `container_ip` and `container_id` from `local.hosts.traefik`. |
| Workspace tests | `../../tests/workspaces/traefik/traefik_test.tftest.hcl` | Verifies canonical remote-state shape and empty fallback behavior. |

## CONVENTIONS
- Keep this workspace app-config-only until real Traefik provider resources are added.
- Keep host metadata sourced from `100-pve` remote state; do not fork inventory data here.
- Preserve empty defaults in `terraform_remote_state.infra` so CI can plan without Tier-0 state present.
- Local apply stays disabled; use `make plan SVC=traefik` or `make validate SVC=traefik` for local review only.

## ANTI-PATTERNS
- Do not hardcode Traefik IPs or VMIDs here; consume `host_inventory` only.
- Do not move LXC lifecycle or rendered config deployment into this workspace; `100-pve` owns both.
- Do not add service-runtime template guidance here; keep that in `../AGENTS.md` and `../templates/`.

## COMMANDS
```bash
make plan SVC=traefik
make validate SVC=traefik
cd tests/workspaces/traefik && terraform init -backend=false && terraform test -filter=traefik_test.tftest.hcl
```
