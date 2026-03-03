# Secret Management

Single source of truth for the homelab secret lifecycle. All secrets flow through 1Password into Terraform workspaces, then via config-renderer to runtime .env files on LXC/VM hosts.

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
1Password (homelab vault, 14 items)
  │
  ├── onepassword-secrets module (39 secret keys)
  │     │
  │     ├── 104-grafana/terraform ──────────────┐
  │     ├── 105-elk/terraform ────────────────┤
  │     ├── 300-cloudflare ───────────────────┤
  │     └── 100-pve (via versions.tf provider) ┤
  │           │
  │           ▼
  │     config-renderer module (templates .tftpl)
  │           │
  │           ▼
  │     rendered .env / .yml / docker-compose files
  │           │
  │           ▼
  │     cloud-init deploy to LXC/VM hosts
  │
  ├── sync-vault-secrets.sh → GitHub Actions Secrets
  │
  └── MCPHub .env (OP_SERVICE_ACCOUNT_TOKEN for MCP servers)
        LXC 112 at /opt/mcphub/.env
```

## 1Password Item Inventory

The shared module (`modules/shared/onepassword-secrets/`) manages 14 items:

| Item         | Description          | Key Secrets                                                                                                                  |
| ------------ | -------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `grafana`    | Observability stack  | `service_account_token`, `admin_password`                                                                                    |
| `glitchtip`  | Error tracking       | `django_secret_key`, `database_url`, `redis_url`                                                                             |
| `proxmox`    | Hypervisor API       | `api_token_id`, `api_token_secret`                                                                                           |
| `github`     | GitHub PAT           | `personal_access_token`                                                                                                      |
| `exa`        | Exa search API       | `api_key`                                                                                                                    |
| `supabase`   | Self-hosted Supabase | `postgres_password`, `jwt_secret`, `anon_key`, `service_role_key`, `dashboard_password`                                      |
| `archon`     | Archon MCP           | `openai_api_key`                                                                                                             |
| `cloudflare` | CF account           | `account_id`, `zone_id`, `api_token`                                                                                         |
| `n8n`        | n8n automation       | `encryption_key`, `webhook_url`                                                                                              |
| `mcphub`     | MCPHub service       | `admin_password`, `n8n_api_key`, `op_token`, `github_pat`, `glitchtip_token`, `es_password`, `proxmox_token`, `slack_tokens` |
| `elk`        | ELK stack            | `elastic_password`, `kibana_password`                                                                                        |
| `synology`   | Synology NAS         | `username`, `password`                                                                                                       |
| `slack`      | Slack workspace      | `bot_token`, `app_token`                                                                                                     |
| `youtube`    | YouTube API          | `client_id`, `client_secret`, `access_token`, `refresh_token`                                                               |

**Module outputs:**

- 39 secret keys (sensitive=true, not printed in Terraform output)
- 11 metadata keys (sensitive=false)

**Access pattern:**

```hcl
# Simplified (preferred)
module.secrets.secrets["grafana_service_account_token"]

# Verbose with fallback
try(module.secrets.secrets["grafana_service_account_token"], section_map["secrets"].field_map["service_account_token"].value, "")
```

## Workspace Integration

| Workspace             | Has onepassword.tf       | Key Secrets Consumed                               |
| --------------------- | ------------------------ | -------------------------------------------------- |
| 100-pve               | via versions.tf provider | `proxmox_api_token`, all template secrets          |
| 104-grafana/terraform | ✅                       | `grafana_service_account_token`, `n8n_webhook_url` |
| 105-elk/terraform     | ✅                       | `elk_elastic_password`                             |
| 300-cloudflare        | ✅                       | `cloudflare_account_id`, `zone_id`, `github_token` |
| 320-slack             | ✅                       | `slack_bot_token`                                  |
| 102-traefik           | ❌                       | —                                                  |
| 108-archon            | ❌                       | —                                                  |

## Runtime Secret Distribution

Per-host `.env` secrets deployed via config-renderer templates:

| Host          | Secrets                                                                                                                                    |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| 102-traefik   | `homelab_tunnel_token` (via cloudflared compose)                                                                                           |
| 104-grafana   | `GRAFANA_ADMIN_PASSWORD`                                                                                                                   |
| 105-elk       | `elastic_password`, `kibana_password` (in docker-compose env vars)                                                                         |
| 106-glitchtip | `DJANGO_SECRET_KEY`, `DATABASE_URL` (with password), `REDIS_URL`                                                                           |
| 107-supabase  | `POSTGRES_PASSWORD`, `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY`, `DASHBOARD_PASSWORD`                                                    |
| 108-archon    | `OPENAI_API_KEY`                                                                                                                           |
| 112-mcphub    | 10+ secrets (`admin_password`, `n8n_api_key`, `op_token`, `github_pat`, `glitchtip_token`, `es_password`, `proxmox_token`, `slack_tokens`) |
| 112-n8n       | `api_key`, `github_token`, `glitchtip_api_token`                                                                                           |

## Provider Authentication

The `OP_CONNECT_TOKEN` and `OP_CONNECT_HOST` environment variables authenticate the Terraform provider to 1Password via the Connect Server on LXC 112 (port 8090).

**Token location:** LXC 112 at `/opt/mcphub/.env`

**Local Terraform runs:** The provider falls back to `OP_CONNECT_TOKEN` and `OP_CONNECT_HOST` env vars when `op_service_account_token` variable is empty (default). Set these locally:

```bash
export OP_CONNECT_TOKEN=$(ssh root@192.168.50.112 'grep OP_SERVICE_ACCOUNT_TOKEN /opt/mcphub/.env | cut -d= -f2-')
export OP_CONNECT_HOST="http://192.168.50.112:8090"
terraform plan
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

## Secret Inventory (GitHub Actions)

### 1Password-Sourced (via `sync-vault-secrets.sh`)

| Secret                | 1Password Reference                                  | Field                   | Priority |
| --------------------- | ---------------------------------------------------- | ----------------------- | -------- |
| `TF_VAR_GRAFANA_AUTH` | `op://homelab/grafana/secrets/service_account_token` | `service_account_token` | P1       |
| `TF_VAR_GITHUB_TOKEN` | `op://homelab/github/secrets/personal_access_token`  | `personal_access_token` | P1       |
| `TF_VAR_SUPABASE_URL` | `op://homelab/supabase/secrets/url`                  | `url`                   | P1       |
| `GH_PAT`              | `op://homelab/github/secrets/personal_access_token`  | `personal_access_token` | P2       |

### Derived (known infrastructure)

| Secret                   | Value                                | Priority |
| ------------------------ | ------------------------------------ | -------- |
| `TF_VAR_N8N_WEBHOOK_URL` | `http://192.168.50.112:5678/webhook` | P1       |

### From local `.tfvars` (via `setup-github-secrets.sh`)

| Secret                         | Source File                       | Variable                | Priority |
| ------------------------------ | --------------------------------- | ----------------------- | -------- |
| `TF_VAR_PROXMOX_ENDPOINT`      | `100-pve/terraform.tfvars`        | `proxmox_endpoint`      | P0       |
| `TF_VAR_PROXMOX_API_TOKEN`    | `100-pve/terraform.tfvars`        | `proxmox_api_token`     | P0       |
| `TF_VAR_PROXMOX_INSECURE`     | `100-pve/terraform.tfvars`        | `proxmox_insecure`      | P0       |
| `TF_VAR_CLOUDFLARE_ACCOUNT_ID`| `300-cloudflare/terraform.tfvars` | `cloudflare_account_id` | P1       |
| `TF_VAR_CLOUDFLARE_ZONE_ID`   | `300-cloudflare/terraform.tfvars` | `cloudflare_zone_id`    | P1       |
| `TF_VAR_SYNOLOGY_DOMAIN`      | `300-cloudflare/terraform.tfvars` | `synology_domain`       | P1       |
| `TF_VAR_ACCESS_ALLOWED_EMAILS` | `300-cloudflare/terraform.tfvars` | `access_allowed_emails` | P1       |
| `CLOUDFLARE_API_TOKEN`        | env / CF dashboard                | —                       | P2       |
| `CLOUDFLARE_ACCOUNT_ID`       | `300-cloudflare/terraform.tfvars` | `cloudflare_account_id` | P2       |

### Manual (3/17 — not in 1Password)

| Secret                    | Priority | Source                                  | Used By                     |
| ------------------------- | -------- | --------------------------------------- | --------------------------- |
| `TF_API_TOKEN`            | P0       | Terraform Cloud (skip if not using TFC) | terraform-plan/apply, drift |
| `CF_ACCESS_CLIENT_ID`     | P2       | CF Zero Trust → Service Tokens          | internal-service-access     |
| `CF_ACCESS_CLIENT_SECRET` | P2       | CF Zero Trust → Service Tokens          | internal-service-access     |

## Secret Rotation

```bash
# 1. Update value in 1Password
#    Via UI: 1Password → homelab vault → item → Edit field
#    Via CLI: op item edit "cloudflare" "secrets.account_id=NEW" --vault homelab

# 2. Push to GitHub
scripts/sync-vault-secrets.sh --force

# 3. Verify
scripts/setup-github-secrets.sh --audit
```

## Weekly Audit

The `secret-audit.yml` workflow runs every Monday at 09:00 UTC.
It validates all 17 secrets and reports missing ones.
Trigger manually: Actions → Secret Audit → Run workflow.

## Credential Rotation Reminder

The `credential-rotation-reminder.yml` workflow runs weekly on Monday at 09:00 UTC.
It checks known expiry dates and creates GitHub issues if any credential is within 14 days of expiry.
Credentials tracked:
- n8n MCP API Key (fixed expiry: 2026-05-11)
- Cloudflare Access service token (60-day rotation cycle via terraform)

## Cross-References

- [Cloudflare Token Rotation](../cloudflare-token-rotation.md)
- [Credential Rotation Runbook](../runbooks/credential-rotation.md)
