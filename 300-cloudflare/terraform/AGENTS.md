# AGENTS: 300-cloudflare/terraform — Cloudflare Infrastructure

## OVERVIEW
Terraform workspace managing Cloudflare DNS, tunnels, and Workers.

## STRUCTURE
```
terraform/
├── main.tf                # Provider, zones, records
├── tunnels.tf             # Cloudflare Tunnel configs
├── workers.tf             # Workers deployment
├── variables.tf           # API token, zone ID
└── versions.tf            # Provider constraints
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| DNS records | `main.tf` | A, CNAME, TXT for jclee.me |
| Tunnels | `tunnels.tf` | Argo tunnel configurations |
| Workers | `workers.tf` | Cloudflare Workers scripts |
| API token | `variables.tf` | From 1Password |

## CONVENTIONS
- Zone ID and API token from 1Password
- Use `cloudflare_record` for DNS
- Use `cloudflare_tunnel` for private origins

## ANTI-PATTERNS
- NEVER commit API tokens
- NEVER use hardcoded zone IDs
- NEVER mix prod/staging in same workspace

## COMMANDS
```bash
terraform plan              # Preview DNS/Workers changes
terraform apply             # Apply changes
```
