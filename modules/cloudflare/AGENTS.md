# AGENTS: modules/cloudflare - Cloudflare Module Family

## OVERVIEW
Reusable Cloudflare Terraform modules. Current scope is the tunnel module used by `300-cloudflare/terraform`.

## STRUCTURE
```text
modules/cloudflare/
└── tunnel/
    ├── main.tf       # Tunnel resource, token/secret generation, lifecycle
    ├── variables.tf  # Account/name inputs
    └── outputs.tf    # Tunnel IDs and connection metadata
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Tunnel module contract | `tunnel/main.tf` | Reusable Cloudflare tunnel resource shape. |
| Inputs | `tunnel/variables.tf` | Account ID, tunnel name, and required descriptions. |
| Outputs | `tunnel/outputs.tf` | IDs/metadata consumed by Cloudflare workspaces. |
| Consumer workspace | `../../300-cloudflare/terraform/AGENTS.md` | Production DNS/tunnel wiring. |
| Module tests | `../../tests/modules/cloudflare/` | Native `terraform test` contract checks. |

## CONVENTIONS
- Keep this module provider-focused; no homelab service inventory or DNS records here.
- Expose stable outputs for consumers; prefer additive variables before breaking the contract.
- Keep generated tunnel secrets sensitive and resource-owned.

## ANTI-PATTERNS
- Do not hardcode account IDs, zone IDs, service hostnames, or origin IPs in the module.
- Do not mix `300-cloudflare/terraform` workspace policy into the reusable module.
- Do not duplicate tunnel resources directly in consumers when this module can own the shape.
