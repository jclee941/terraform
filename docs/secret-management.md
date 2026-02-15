# Secret Management

GitHub Actions secrets for CI/CD workflows in `qws941/terraform`.

## Quick Start

```bash
# Sync all secrets from Vault → GitHub (recommended)
scripts/sync-vault-secrets.sh

# Audit Vault sync state
scripts/sync-vault-secrets.sh --audit

# Force rotation (overwrite existing)
scripts/sync-vault-secrets.sh --force

# Fallback: resolve from .tfvars + Vault + env vars
scripts/setup-github-secrets.sh
scripts/setup-github-secrets.sh --audit
```

## Architecture

```
HashiCorp Vault (192.168.50.112:8200)
  secret/homelab/cloudflare  → R2 creds, account ID
  secret/homelab/grafana     → service account token
  secret/homelab/github      → PAT
  secret/homelab/supabase    → URL, service key
      │
      ▼
sync-vault-secrets.sh  ──→  GitHub Actions Secrets (qws941/terraform)
      │                           │
      │                           ├── terraform-plan/apply (6 workspaces)
      │                           ├── terraform-drift
      │                           ├── worker-deploy
      │                           └── secret-audit (weekly)
      │
setup-github-secrets.sh  ──→  Fallback: .tfvars + Vault + env vars
      │
secrets.yaml (300-cloudflare)  ──→  Metadata SSoT for all repos
```

## Secret Inventory (17/20 automated)

### Vault-Sourced (via `sync-vault-secrets.sh`)

| Secret | Vault Path | Field | Priority |
|--------|-----------|-------|----------|
| `AWS_ACCESS_KEY_ID` | `secret/homelab/cloudflare` | `r2_access_key_id` | P0 |
| `AWS_SECRET_ACCESS_KEY` | `secret/homelab/cloudflare` | `r2_secret_access_key` | P0 |
| `TF_VAR_GRAFANA_AUTH` | `secret/homelab/grafana` | `service_account_token` | P1 |
| `TF_VAR_GITHUB_TOKEN` | `secret/homelab/github` | `personal_access_token` | P1 |
| `TF_VAR_SUPABASE_URL` | `secret/homelab/supabase` | `url` | P1 |
| `GH_PAT` | `secret/homelab/github` | `personal_access_token` | P2 |

### Derived (known infrastructure)

| Secret | Value | Priority |
|--------|-------|----------|
| `TF_VAR_N8N_WEBHOOK_URL` | `http://192.168.50.112:5678/webhook` | P1 |

### From local `.tfvars` (via `setup-github-secrets.sh`)

| Secret | Source File | Variable | Priority |
|--------|-----------|----------|----------|
| `TF_VAR_PROXMOX_ENDPOINT` | `100-pve/terraform.tfvars` | `proxmox_endpoint` | P0 |
| `TF_VAR_PROXMOX_API_TOKEN` | `100-pve/terraform.tfvars` | `proxmox_api_token` | P0 |
| `TF_VAR_PROXMOX_INSECURE` | `100-pve/terraform.tfvars` | `proxmox_insecure` | P0 |
| `TF_VAR_VAULT_TOKEN` | `100-pve/terraform.tfvars` | `vault_token` | P1 |
| `TF_VAR_CLOUDFLARE_ACCOUNT_ID` | `300-cloudflare/terraform.tfvars` | `cloudflare_account_id` | P1 |
| `TF_VAR_CLOUDFLARE_ZONE_ID` | `300-cloudflare/terraform.tfvars` | `cloudflare_zone_id` | P1 |
| `TF_VAR_SYNOLOGY_DOMAIN` | `300-cloudflare/terraform.tfvars` | `synology_domain` | P1 |
| `TF_VAR_ACCESS_ALLOWED_EMAILS` | `300-cloudflare/terraform.tfvars` | `access_allowed_emails` | P1 |
| `CLOUDFLARE_API_TOKEN` | env / CF dashboard | — | P2 |
| `CLOUDFLARE_ACCOUNT_ID` | `300-cloudflare/terraform.tfvars` | `cloudflare_account_id` | P2 |

### Manual (3/20 — not in Vault)

| Secret | Priority | Source | Used By |
|--------|----------|--------|---------|
| `TF_API_TOKEN` | P0 | Terraform Cloud (skip if not using TFC) | terraform-plan/apply, drift |
| `CF_ACCESS_CLIENT_ID` | P2 | CF Zero Trust → Service Tokens | internal-service-access |
| `CF_ACCESS_CLIENT_SECRET` | P2 | CF Zero Trust → Service Tokens | internal-service-access |

## Secret Rotation

```bash
# 1. Update value in Vault
vault kv put secret/homelab/cloudflare r2_access_key_id="NEW" r2_secret_access_key="NEW" ...

# 2. Push to GitHub
scripts/sync-vault-secrets.sh --force

# 3. Verify
scripts/setup-github-secrets.sh --audit
```

## Weekly Audit

The `secret-audit.yml` workflow runs every Monday at 09:00 UTC.
It validates all 20 secrets and reports missing ones.
Trigger manually: Actions → Secret Audit → Run workflow.
