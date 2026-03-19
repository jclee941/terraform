# AGENTS: 100-pve/envs/prod — Host Inventory SoT

## OVERVIEW
Production host inventory source of truth. `hosts.tf` defines VMID, IP, role, and port mappings consumed by `module.hosts`.

## STRUCTURE
```
100-pve/envs/prod/
├── hosts.tf        # Canonical host/network map consumed by module.hosts
├── README.md       # Environment notes
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Add or change host metadata | `hosts.tf` → `locals.hosts` | One entry per host key. |
| Update network defaults | `hosts.tf` → `locals.network` | Subnet/gateway/domain values. |
| Exported inventory surface | `hosts.tf` → `output "hosts"` | Downstream modules consume this shape. |
| Downstream consumption in 100-pve | `../../main.tf`, `../../locals.tf` | `module.hosts.hosts` feeds provisioning and config render locals. |
| Service template usage | `../../../{NNN}-*/templates/*.tftpl` | Host IPs/ports are interpolated into rendered service configs. |
| Parent workspace rules | `../../AGENTS.md` | SSoT and full workspace data flow contract. |

## CONVENTIONS
- Keep host keys stable (`runner`, `traefik`, `grafana`, etc.).
- Preserve object shape for each host: `vmid`, `ip`, `roles`, `ports`.
- Keep VMID in managed range and aligned with service directory numbering.
- Keep ports map explicit; use `{}` when no exposed ports.

## ANTI-PATTERNS
- Do not hardcode host IPs in other Terraform roots; edit this file instead.
- Do not change host object keys/field names without updating downstream references.
- Do not store secrets or credentials in host metadata.

## COMMANDS
```bash
make plan SVC=pve
terraform -chdir=100-pve plan
```
