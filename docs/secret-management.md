# Secret Management

GitHub Actions secrets for CI/CD workflows in `qws941/terraform`.

## Quick Start

```bash
# Sync all secrets from 1Password → GitHub (recommended)
scripts/sync-vault-secrets.sh

# Audit 1Password sync state
scripts/sync-vault-secrets.sh --audit

# Force rotation (overwrite existing)
scripts/sync-vault-secrets.sh --force

# Fallback: resolve from .tfvars + 1Password + env vars
scripts/setup-github-secrets.sh
scripts/setup-github-secrets.sh --audit
```

## Architecture

```
1Password (Homelab vault)
  op://Homelab/cloudflare  → account ID
  op://Homelab/grafana     → service account token
  op://Homelab/github      → PAT
  op://Homelab/supabase    → URL, service key
      │
      ▼
sync-vault-secrets.sh  ──→  GitHub Actions Secrets (qws941/terraform)
      │                           │
      │                           ├── terraform-plan/apply (6 workspaces)
      │                           ├── terraform-drift
      │                           ├── worker-deploy
      │                           └── secret-audit (weekly)
      │
setup-github-secrets.sh  ──→  Fallback: .tfvars + 1Password + env vars
      │
secrets.yaml (300-cloudflare)  ──→  Metadata SSoT for all repos
```

## Terraform Secret Backend

Secrets are consumed at plan-time via the `onepassword-secrets` shared module:

```hcl
module "secrets" {
  source                   = "../modules/shared/onepassword-secrets"
  op_vault_id              = var.op_vault_id
  op_service_account_token = var.op_service_account_token
}

# Access: module.secrets.secrets["grafana_admin_password"]
```

Provider authentication: `OP_SERVICE_ACCOUNT_TOKEN` environment variable.

## Secret Inventory (15/17 automated)

### 1Password-Sourced (via `sync-vault-secrets.sh`)

| Secret | 1Password Reference | Field | Priority |
|--------|---------------------|-------|----------|
| `TF_VAR_GRAFANA_AUTH` | `op://Homelab/grafana/secrets/service_account_token` | `service_account_token` | P1 |
| `TF_VAR_GITHUB_TOKEN` | `op://Homelab/github/secrets/personal_access_token` | `personal_access_token` | P1 |
| `TF_VAR_SUPABASE_URL` | `op://Homelab/supabase/secrets/url` | `url` | P1 |
| `GH_PAT` | `op://Homelab/github/secrets/personal_access_token` | `personal_access_token` | P2 |

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
| `TF_VAR_CLOUDFLARE_ACCOUNT_ID` | `300-cloudflare/terraform.tfvars` | `cloudflare_account_id` | P1 |
| `TF_VAR_CLOUDFLARE_ZONE_ID` | `300-cloudflare/terraform.tfvars` | `cloudflare_zone_id` | P1 |
| `TF_VAR_SYNOLOGY_DOMAIN` | `300-cloudflare/terraform.tfvars` | `synology_domain` | P1 |
| `TF_VAR_ACCESS_ALLOWED_EMAILS` | `300-cloudflare/terraform.tfvars` | `access_allowed_emails` | P1 |
| `CLOUDFLARE_API_TOKEN` | env / CF dashboard | — | P2 |
| `CLOUDFLARE_ACCOUNT_ID` | `300-cloudflare/terraform.tfvars` | `cloudflare_account_id` | P2 |

### Manual (3/17 — not in 1Password)

| Secret | Priority | Source | Used By |
|--------|----------|--------|---------|
| `TF_API_TOKEN` | P0 | Terraform Cloud (skip if not using TFC) | terraform-plan/apply, drift |
| `CF_ACCESS_CLIENT_ID` | P2 | CF Zero Trust → Service Tokens | internal-service-access |
| `CF_ACCESS_CLIENT_SECRET` | P2 | CF Zero Trust → Service Tokens | internal-service-access |

## Secret Rotation

```bash
# 1. Update value in 1Password
#    Via UI: 1Password → Homelab vault → item → Edit field
#    Via CLI: op item edit "cloudflare" "secrets.account_id=NEW" --vault Homelab

# 2. Push to GitHub
scripts/sync-vault-secrets.sh --force

# 3. Verify
scripts/setup-github-secrets.sh --audit
```

## Weekly Audit

The `secret-audit.yml` workflow runs every Monday at 09:00 UTC.
It validates all 17 secrets and reports missing ones.
Trigger manually: Actions → Secret Audit → Run workflow.
