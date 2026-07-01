# AGENTS: 300-cloudflare/terraform — Cloudflare Infrastructure

## OVERVIEW
Terraform workspace managing Cloudflare DNS, tunnels, Worker bindings/routes, Logpush, R2, WAF, and 1Password-backed provider inputs.

## STRUCTURE
```
terraform/
├── main.tf                # Provider bootstrap
├── dns.tf                 # DNS records
├── tunnel.tf              # Cloudflare Tunnel configs
├── workers.tf             # Worker script/route wiring
├── logpush.tf             # Worker trace Logpush
├── onepassword.tf         # Secret/metadata lookup
├── secrets-store.tf       # CF Secrets Store sync resources
├── validation.tf/checks.tf # Input and metadata checks
├── r2.tf, waf.tf          # R2 bucket and WAF rules
├── outputs*.tf            # Split outputs by consumer
├── variables.tf           # Inputs and feature flags
└── versions.tf            # Provider constraints
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| DNS records | `dns.tf` | CNAMEs for HTTP, TCP, and logstash-ingest. |
| Tunnels | `tunnel.tf` | Cloudflare tunnel resources and moved blocks. |
| Worker wiring | `workers.tf` | Worker routes, services, and bindings. |
| Secret inventory | `../inventory/secrets.yaml`, `locals.tf`, `secrets-store.tf` | Metadata-driven secret target handling. |
| Provider credentials | `onepassword.tf`, `variables.tf` | 1Password first, variable fallback for break-glass. |
| Removed Access | `access.tf` | Tombstone; Access resources are not active. |

## CONVENTIONS
- Prefer 1Password-derived Cloudflare metadata; keep variable fallback explicit and validated.
- Keep service hostnames in `locals.tf`; avoid duplicating them across DNS/tunnel files.
- Use feature flags (`enable_cf_store_sync`, `enable_worker_route`) for side-effectful resources.

## ANTI-PATTERNS
- NEVER commit API tokens
- NEVER use hardcoded zone IDs unless a variable default is intentionally documented and validated.
- NEVER mix prod/staging in same workspace
- NEVER run local apply; apply via CI/CD.

## COMMANDS
```bash
terraform -chdir=300-cloudflare/terraform init -backend=false
terraform -chdir=300-cloudflare/terraform plan
# apply via CI/CD only
```
