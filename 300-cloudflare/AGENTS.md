# AGENTS: 300-cloudflare

## OVERVIEW

Cloudflare infrastructure hub: 33 secret metadata entries, Cloudflare tunnels, DNS, Logpush, R2 storage, WAF, and two Cloudflare Workers (`synology-proxy`, `issue-form`). Cloudflare Access policy resources have been removed; `access.tf` is a tombstone.

## STRUCTURE

```
300-cloudflare/
├── AGENTS.md                # This file
├── terraform/               # Terraform workspace (DNS, tunnels, workers, Logpush, R2, WAF)
├── workers/
│   ├── synology-proxy/      # Hono Worker: Synology FileStation proxy + R2 cache
│   └── issue-form/          # Hono Worker: issue form + ELK webhook
├── scripts/
│   ├── collect.go           # Harvest .env/.tfvars from sibling projects
│   ├── audit.go             # Drift detection: inventory vs actual
│   ├── sync.go              # Push secrets to targets (CF/GitHub/Vault)
│   └── generate-bindings.go # Generate wrangler secret bindings
├── inventory/
│   └── secrets.yaml         # SSoT: secret metadata registry (NO values)
├── docker/
│   └── cloudflared/         # Legacy Docker connector reference
└── docs/
    └── requirements.md      # Feature requirements
```

## WHERE TO LOOK

| Task                      | Location                                                            | Notes                                                                                                                   |
| ------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **Add/modify a secret**   | `inventory/secrets.yaml` then `terraform/*.tf`                      | YAML defines metadata; Terraform/scripts target stores.                                                                 |
| **Secret target logic**   | `terraform/locals.tf`                                               | YAML parsing + target classification.                                                                                   |
| **DNS records**           | `terraform/dns.tf`                                                  | CNAME records for homelab, TCP, and logstash-ingest subdomains.                                                         |
| **Tunnel config**         | `terraform/tunnel.tf` + native service on cliproxy VM 114             | Tunnels: Synology direct, homelab direct origins + TCP/logstash, and jclee workstation.                                   |
| **Access tombstone**      | `terraform/access.tf`                                               | Access resources removed; do not document new policy here without recreating resources.                                  |
| **TCP tunnels (SSH/RDP)** | `terraform/locals.tf` → `tcp_services` + `terraform/tunnel.tf` + `terraform/dns.tf` | synology-ssh, rdp, oc-rdp, jclee-ssh, youtube-ssh, ssh; use direct origins. |
| **Logpush**               | `terraform/logpush.tf`                                              | Worker trace events → HTTPS `logstash-ingest.jclee.me` → Logstash HTTP ingest.                                          |
| **WAF rules**             | `terraform/waf.tf`                                                  | Web Application Firewall custom rulesets.                                                                               |
| **R2 storage**            | `terraform/r2.tf`                                                   | `synology-cache` bucket (APAC, 7d TTL).                                                                                 |
| **Secret scripts**        | `scripts/AGENTS.md`                                                 | Go CLIs for collect/audit/sync/bindings.                                                                                |
| **Workers**               | `workers/AGENTS.md`                                                 | Hono TS apps with separate configs/tests.                                                                               |
| **1Password secrets**     | `terraform/onepassword.tf` + `terraform/validation.tf`              | Structured lookup via `modules/shared/onepassword-secrets`.                                                             |
| **Homelab service map**   | `terraform/locals.tf` → `homelab_services`                          | HTTP CNAMEs and TCP entries route directly to declared service origins.  |
| **CI**                    | `.github/workflows/`                                                | Repo-level workflows; worker deploys stay CI-gated.                                                                     |

## CONVENTIONS

- **Numbering**: 300+ = external infrastructure providers (not mapped to `192.168.50.x`).
- **Providers**: cloudflare ~5.0, github ~6.0, onepassword. Auth via `CLOUDFLARE_API_TOKEN` env var + 1Password service account.
- **Feature flags**: `enable_cf_store_sync`, `enable_worker_route` in `variables.tf`.
- **Secret values**: NEVER in code/git. Only in `.tfvars` (gitignored) or env vars.
- **inventory/secrets.yaml**: Metadata only (name, targets[], description). No values.
- **Scripts**: Assume `~/dev/` sibling project layout for cross-project harvesting.
- **Tunnel architecture**: `synology` direct to NAS, `homelab` direct to HTTP/TCP/logstash origins, and `jclee` for the physical PC.
- **Access status**: Cloudflare Access is currently removed. Do not assume email-auth or M2M policy resources exist.

## ANTI-PATTERNS

- **NEVER** commit `.tfvars`, `.env`, or `data/` output files.
- **NEVER** commit `.tfstate` files. Backend is local; state stays untracked.
- `collect.go` output files contain `# DO NOT COMMIT` header — respect it.
- CF Secrets Store sync (`enable_cf_store_sync`) is beta — don't enable without testing.
- Worker route (`enable_worker_route`) requires Worker deployed via wrangler first.

## COMMANDS

```bash
terraform -chdir=terraform init && terraform -chdir=terraform plan # TF workspace (apply via CI only)
cd workers/synology-proxy && npm run dev               # Worker dev
cd workers/synology-proxy && npm test                            # Worker test (deploy via CI only)
go run ./scripts/audit.go && go run ./scripts/sync.go             # Secret audit + sync
```

## NOTES
- R2 bucket `synology-cache`: APAC region, 7-day TTL. Worker uses SID-based Synology FileStation auth (50min session cache).
- `audit.go` scans hardcoded sibling project dirs — update when adding projects.
- Logpush pipeline: CF Worker traces → `logpush.tf` job → HTTPS `logstash-ingest.jclee.me` → CF tunnel → Logstash `:8080` → `logs-cloudflare-workers-*`.
- TCP tunnels connect directly to origin IPs via variables (`var.jclee_ip`, `var.jclee_dev_ip`, `var.synology_nas_ip`, `var.youtube_ip`). Migrated from `~/dev/cloudflare/` (2026-02-13).
