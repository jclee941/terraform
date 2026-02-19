# PROJECT KNOWLEDGE BASE: 300-CLOUDFLARE

**Updated:** 2026-02-13
**Provider:** External (Cloudflare)
**Domain:** jclee.me / jclee.win

## OVERVIEW
Cloudflare secrets management hub and Synology NAS proxy Worker. Centralized orchestrator managing 50+ secrets across CF Secrets Store and GitHub Actions for 12+ sibling projects. Includes Cloudflare tunnel, DNS, Access policies, R2 storage, and a Synology FileStation proxy Worker.

## STRUCTURE
```
300-cloudflare/
├── BUILD.bazel              # Monorepo integration
├── OWNERS                   # Access control
├── AGENTS.md                # This file
├── *.tf                     # Terraform workspace (14 TF files)
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
| **DNS records** | `dns.tf` | Cloudflare DNS zone records |
| **Tunnel config** | `tunnel.tf` + `docker/cloudflared/` | TF creates tunnel, Docker runs connector |
| **Access policies** | `access.tf` | CF Access email-based policies |
| **R2 storage** | `r2.tf` | `synology-cache` bucket (APAC, 7d TTL) |
| **GitHub secrets** | `github-secrets.tf` | Cross-repo GitHub Actions secrets |
| **Worker** | `workers/synology-proxy/` | Hono TS app with FileStation proxy |
| **CI** | Migrated from `.github/workflows/ci.yml` | 2 jobs: worker + terraform |

## CONVENTIONS
- **Numbering**: 300+ = external infrastructure providers (not mapped to `192.168.50.x`).
- **Providers**: cloudflare ~5.0, github ~6.0. Auth via `CLOUDFLARE_API_TOKEN` env var (no 1Password).
- **Feature flags**: `enable_cf_store_sync`, `enable_worker_route` in `variables.tf`.
- **Secret values**: NEVER in code/git. Only in `.tfvars` (gitignored) or env vars.
- **inventory/secrets.yaml**: Metadata only (name, targets[], description). No values.
- **Scripts**: Assume `~/dev/` sibling project layout for cross-project harvesting.

## ANTI-PATTERNS
- **NEVER** commit `.tfvars`, `.env`, or `data/` output files.
- **NEVER** commit `.tfstate` files. Backend is local (state stored on disk).
- `collect.sh` output files contain `# DO NOT COMMIT` header — respect it.
- CF Secrets Store sync (`enable_cf_store_sync`) is beta — don't enable without testing.
- Worker route (`enable_worker_route`) requires Worker deployed via wrangler first.

## COMMANDS
```bash
# Terraform
cd 300-cloudflare && terraform init
terraform plan
terraform apply

# Worker
cd 300-cloudflare/workers/synology-proxy
npm install && npm run dev    # wrangler dev
npm test                      # vitest
npm run deploy                # wrangler deploy

# Scripts
./300-cloudflare/scripts/collect.sh   # harvest secrets
./300-cloudflare/scripts/audit.sh     # check drift
```

## NOTES
- R2 bucket `synology-cache` in APAC region, 7-day TTL.
- Tunnel exposes Synology at `synology.jclee.win` via CF Access (email policy).
- `collect.sh` scans 12 hardcoded project dirs — update when adding projects.
- Worker uses SID-based auth to Synology FileStation API (50min session cache).
- Migrated from standalone `~/dev/cloudflare/` repo (2026-02-13).
