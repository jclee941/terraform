# Cloudflare Edge Infrastructure Module

## OVERVIEW
Standalone Terraform module for Cloudflare edge services. Manages Zero Trust tunnels, Access applications, DNS records, Workers scripts, and R2 storage. Uses its own provider (`cloudflare/cloudflare ~>5.0`) — NOT part of the main Proxmox provider chain.

## STRUCTURE
```
cloudflare/
├── tunnel.tf           # Zero Trust tunnel + auto-generated secrets
├── access.tf           # Access applications + policies (dynamic include/exclude)
├── dns.tf              # DNS records (manual + auto tunnel CNAMEs)
├── workers.tf          # Workers scripts (R2/KV/D1/secret bindings) + routes
├── r2.tf               # R2 bucket provisioning
├── variables.tf        # 3 required (api_token, account_id, zone_id) + 6 optional maps
├── outputs.tf          # tunnel_ids/tokens, access_app_ids, r2_names, worker_names
├── versions.tf         # Provider constraints (cloudflare ~>5.0, random ~>3.0)
├── provider.tf         # Provider configuration (api_token auth)
└── example.tf.disabled # Reference usage (disabled by default)
```

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Add tunnel | `tunnel.tf` | `for_each` over `var.tunnels` map; secret auto-generated via `random_bytes` |
| Add Access app | `access.tf` | Dynamic blocks for email/domain/group/IP include/exclude |
| Add DNS record | `dns.tf` | Manual records + auto-generated tunnel CNAME entries |
| Add Worker | `workers.tf` | Supports R2, KV, D1, secret_text, plain_text bindings |
| Add R2 bucket | `r2.tf` | Simple `for_each` over `var.r2_buckets` |

## CONVENTIONS
- **Separate State**: This module maintains its own `.terraform/` and `tfstate`. Not integrated into main Proxmox state.
- **Map-driven Resources**: All resources use `for_each` over input maps (tunnels, access_applications, dns_records, etc.).
- **Auto-generated Secrets**: Tunnel secrets use `random_bytes` — never manually specified.
- **Sensitive Outputs**: `tunnel_tokens` marked sensitive. Use `terraform output -json` to extract.

## ANTI-PATTERNS
- **NO committed `.tfvars`**: `.gitignore` blocks `*.tfvars`. Use env vars or Vault.
- **NO hardcoded zone/account IDs**: Always pass via variables.
- **NO direct provider config edits**: API token must come from `var.api_token`, not inline.
