# Secret Management

GitHub Actions secrets required for CI/CD workflows in `qws941/terraform`.

## Quick Start

```bash
# Audit current state
scripts/setup-github-secrets.sh --audit

# Set resolvable secrets from local .tfvars
scripts/setup-github-secrets.sh

# Dry-run first
scripts/setup-github-secrets.sh --dry-run

# Filter by priority
scripts/setup-github-secrets.sh --priority P0
```

## Secret Inventory

### P0 — Required for all Terraform workflows

| Secret | Source | Notes |
|--------|--------|-------|
| `AWS_ACCESS_KEY_ID` | Cloudflare R2 API token | S3-compatible access key for `jclee-tf-state` bucket |
| `AWS_SECRET_ACCESS_KEY` | Cloudflare R2 API token | S3-compatible secret for R2 backend |
| `TF_API_TOKEN` | Terraform Cloud | Only needed if using TFC remote ops |
| `TF_VAR_PROXMOX_ENDPOINT` | `100-pve/terraform.tfvars` → `proxmox_endpoint` | e.g., `https://192.168.50.100:8006/` |
| `TF_VAR_PROXMOX_API_TOKEN` | `100-pve/terraform.tfvars` → `proxmox_api_token` | Format: `user@realm!tokenid=uuid` |
| `TF_VAR_PROXMOX_INSECURE` | `100-pve/terraform.tfvars` → `proxmox_insecure` | `true` for self-signed certs |

### P1 — Individual workspace secrets

| Secret | Source | Workspace |
|--------|--------|-----------|
| `TF_VAR_GRAFANA_AUTH` | Grafana admin UI → API Keys | 104-grafana |
| `TF_VAR_N8N_WEBHOOK_URL` | n8n instance base URL | 104-grafana |
| `TF_VAR_SUPABASE_URL` | Supabase project settings | 108-archon |
| `TF_VAR_CLOUDFLARE_ACCOUNT_ID` | `300-cloudflare/terraform.tfvars` | 300-cloudflare |
| `TF_VAR_CLOUDFLARE_ZONE_ID` | `300-cloudflare/terraform.tfvars` | 300-cloudflare |
| `TF_VAR_SYNOLOGY_DOMAIN` | `300-cloudflare/terraform.tfvars` | 300-cloudflare |
| `TF_VAR_ACCESS_ALLOWED_EMAILS` | `300-cloudflare/terraform.tfvars` | 300-cloudflare |
| `TF_VAR_GITHUB_TOKEN` | GitHub PAT (repo, admin:org) | 300-cloudflare, 301-github |
| `TF_VAR_VAULT_TOKEN` | `100-pve/terraform.tfvars` → `vault_token` | 300-cloudflare |

### P2 — Non-Terraform workflows

| Secret | Source | Workflow |
|--------|--------|----------|
| `CLOUDFLARE_API_TOKEN` | CF dashboard → API Tokens | worker-deploy |
| `CLOUDFLARE_ACCOUNT_ID` | CF dashboard → Account ID | worker-deploy |
| `GH_PAT` | GitHub PAT (public_repo) | milestone-automation |
| `CF_ACCESS_CLIENT_ID` | CF Zero Trust → Service Tokens | internal-service-access |
| `CF_ACCESS_CLIENT_SECRET` | CF Zero Trust → Service Tokens | internal-service-access |

## Value Sources

### From local `.tfvars` (auto-resolved by setup script)

The setup script reads values from:
- `100-pve/terraform.tfvars` — proxmox_endpoint, proxmox_api_token, proxmox_insecure, vault_token
- `300-cloudflare/terraform.tfvars` — cloudflare_account_id, cloudflare_zone_id, synology_domain, access_allowed_emails

### From Cloudflare R2 (manual)

R2 API tokens are created in **Cloudflare Dashboard → R2 → Manage R2 API Tokens**.
Create a token with `Object Read & Write` on the `jclee-tf-state` bucket.
The Access Key ID maps to `AWS_ACCESS_KEY_ID`, Secret Access Key to `AWS_SECRET_ACCESS_KEY`.

### From environment variables (manual)

These require manual `gh secret set` with values from their respective services:
- `GRAFANA_AUTH` — Grafana UI → Administration → Service accounts → Add token
- `N8N_WEBHOOK_URL` — n8n instance URL (e.g., `http://192.168.50.112:5678/webhook`)
- `SUPABASE_URL` — Supabase project settings → API → Project URL
- `GITHUB_TOKEN` / `GH_PAT` — GitHub → Settings → Developer settings → PAT
- `CF_ACCESS_CLIENT_ID/SECRET` — CF Zero Trust → Access → Service Auth → Create Service Token
- `CLOUDFLARE_API_TOKEN` — CF Dashboard → My Profile → API Tokens → Create Token

## Architecture

```
secrets.yaml (metadata SSoT)
     │
     ├── setup-github-secrets.sh    → qws941/terraform (this repo)
     ├── sync.sh                    → jclee-homelab/* repos
     └── audit.sh                   → drift detection
```

## Weekly Audit

The `secret-audit.yml` workflow runs every Monday at 09:00 UTC.
It validates all 20 secrets and reports missing ones.
Trigger manually: Actions → Secret Audit → Run workflow.
