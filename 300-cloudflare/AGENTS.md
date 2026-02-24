# PROJECT KNOWLEDGE BASE: 300-CLOUDFLARE
**Updated:** 2026-02-24
**Provider:** External (Cloudflare)
**Domain:** jclee.me / jclee.win

## OVERVIEW

Cloudflare infrastructure hub: secrets management (50+ secrets across CF Secrets Store + GitHub Actions for 12+ sibling projects), Zero Trust Access (12 HTTP services + 4 TCP tunnels + M2M service token), Cloudflare tunnels, DNS, Logpush, R2 storage, WAF, and a Synology FileStation proxy Worker.
## STRUCTURE
```
300-cloudflare/
├── BUILD.bazel              # Monorepo integration
├── OWNERS                   # Access control
├── AGENTS.md                # This file
├── *.tf                     # Terraform workspace (18 TF files, incl. logpush.tf, waf.tf, onepassword.tf, validation.tf)
├── terraform.tfvars.example # Variable template (NO secrets)
├── workers/
│   └── synology-proxy/      # Hono Worker: Synology FileStation proxy + R2 cache
├── scripts/
│   ├── collect.sh           # Harvest .env/.tfvars from sibling projects
│   ├── audit.sh             # Drift detection: inventory vs actual
│   ├── sync.sh              # Push secrets to targets (CF/GitHub/Vault)
│   └── generate-bindings.sh # Generate wrangler secret bindings
├── inventory/
│   └── secrets.yaml         # SSoT: secret metadata registry (NO values)
├── docker/
│   └── cloudflared/         # Tunnel connector on Synology NAS
└── docs/
    └── requirements.md      # Feature requirements
```
## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Add/modify a secret** | `inventory/secrets.yaml` then `*.tf` | YAML defines targets, TF applies |
| **Secret target logic** | `locals.tf` | YAML parsing + target classification |
| **DNS records** | `dns.tf` | CNAME records for homelab + TCP + logstash-ingest subdomains |
| **Tunnel config** | `tunnel.tf` + `docker/cloudflared/` | 3 tunnels: synology (direct) + homelab (Traefik + TCP + logstash-ingest) + jclee (workstation) |
| **Access policies** | `access.tf` | CF Access: 12 HTTP (24h), 4 TCP (720h), 1 M2M service token (logstash) |
| **TCP tunnels (SSH/RDP)** | `locals.tf` → `tcp_services` + `tunnel.tf` + `dns.tf` + `access.tf` | synology-ssh (:22), rdp (:3389), oc-rdp (:3389), jclee-ssh (:22) — bypass Traefik |
| **Logpush** | `logpush.tf` + `access.tf` | Worker trace events → Logstash HTTP ingest via M2M service token |
| **WAF rules** | `waf.tf` | Web Application Firewall custom rulesets |
| **R2 storage** | `r2.tf` | `synology-cache` bucket (APAC, 7d TTL) |
| **GitHub secrets** | `github-secrets.tf` | Cross-repo GitHub Actions secrets |
| **Worker** | `workers/synology-proxy/` | Hono TS app with FileStation proxy |
| **1Password secrets** | `onepassword.tf` + `validation.tf` | Structured secret lookup via `modules/shared/onepassword-secrets`. |
| **Homelab service map** | `locals.tf` → `homelab_services` | 12 HTTP services via Traefik (elk, kibana, es, glitchtip, grafana, mcphub, vault, archon, supabase, nas, n8n, opencode) |
| **CI** | Migrated from `.github/workflows/ci.yml` | 2 jobs: worker + terraform |

## CONVENTIONS

- **Numbering**: 300+ = external infrastructure providers (not mapped to `192.168.50.x`).
- **Providers**: cloudflare ~5.0, github ~6.0, onepassword. Auth via `CLOUDFLARE_API_TOKEN` env var + 1Password service account.
- **Feature flags**: `enable_cf_store_sync`, `enable_worker_route` in `variables.tf`.
- **Secret values**: NEVER in code/git. Only in `.tfvars` (gitignored) or env vars.
- **inventory/secrets.yaml**: Metadata only (name, targets[], description). No values.
- **Scripts**: Assume `~/dev/` sibling project layout for cross-project harvesting.
- **Tunnel architecture**: 3 tunnels — `synology` (direct to NAS, no_tls_verify), `homelab`/`traefik` (HTTP via Traefik + TCP direct + logstash-ingest), and `jclee` (workstation, VMID 80).
- **Access tiers**: HTTP services get 24h sessions with email auth. TCP services (SSH/RDP) get 720h sessions. M2M (Logpush→Logstash) uses service token with `non_identity` policy.
## ANTI-PATTERNS
- **NEVER** commit `.tfvars`, `.env`, or `data/` output files.
- **NEVER** commit `.tfstate` files. Backend is local (state tracked in git for CI reliability).
- `collect.sh` output files contain `# DO NOT COMMIT` header — respect it.
- CF Secrets Store sync (`enable_cf_store_sync`) is beta — don't enable without testing.
- Worker route (`enable_worker_route`) requires Worker deployed via wrangler first.

## COMMANDS

```bash
terraform init && terraform plan                                # TF workspace (apply via CI only)
cd workers/synology-proxy && npm run dev               # Worker dev
cd workers/synology-proxy && npm test                            # Worker test (deploy via CI only)
./scripts/collect.sh && ./scripts/audit.sh             # Secret harvest + drift
```
## NOTES
- R2 bucket `synology-cache` in APAC region, 7-day TTL.
- Tunnel exposes Synology at `synology.jclee.win` via CF Access (email policy).
- `collect.sh` scans 12 hardcoded project dirs — update when adding projects.
- Worker uses SID-based auth to Synology FileStation API (50min session cache).
- Migrated from standalone `~/dev/cloudflare/` repo (2026-02-13).
- Logpush pipeline: CF Worker traces → `logpush.tf` job → HTTPS to `logstash-ingest.jclee.me` → CF tunnel → Logstash `:8080` HTTP input → `logs-cloudflare-workers-*` ES indices.
- Logpush M2M service token (`logpush`) has 8760h (1yr) duration; rotated via `access.tf`.
- TCP tunnels bypass Traefik entirely and connect directly to origin IPs via variables (`var.jclee_ip`, `var.jclee_dev_ip`, `var.synology_nas_ip`).
