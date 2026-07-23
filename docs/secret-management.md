# Secret Management

Single source of truth for the homelab secret lifecycle. All secrets flow through 1Password into Terraform workspaces, then via config-renderer to runtime .env files on LXC/VM hosts.

## Quick Start

```bash
# Sync all secrets from 1Password → GitHub (recommended)
go run scripts/sync-vault-secrets.go

# Audit 1Password sync state
go run scripts/sync-vault-secrets.go --audit

# Force rotation (overwrite existing)
go run scripts/sync-vault-secrets.go --force

# Fallback: resolve from .tfvars + 1Password + env vars
go run scripts/setup-github-secrets.go
go run scripts/setup-github-secrets.go --audit
```

## Architecture

#### Diagram summary 1

- Type: flowchart
- 1Password vault\nhomelab (Vault) -> onepassword-secrets module (Module)
- onepassword-secrets module (Module) -> Terraform workspaces (Terraform)
- Terraform workspaces (Terraform) -> templatefile() rendering (Templates)
- templatefile() rendering (Templates) -> Runtime .env / config files (Runtime)
- Terraform workspaces (Terraform) -> GitHub Actions secrets sync (GH)
- GitHub Actions secrets sync (GH) -> CI/CD workflows (CI)


## 1Password Item Inventory

The shared module (`modules/shared/onepassword-secrets/`) manages core homelab and optional service items:

| Item         | Description          | Key Secrets                                                                                                                  |
| ------------ | -------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `proxmox`    | Hypervisor API       | `api_token_id`, `api_token_secret`                                                                                           |
| `github`     | GitHub PAT           | `personal_access_token`                                                                                                      |

| `cloudflare` | CF account           | `account_id`, `zone_id`, `api_token`                                                                                         |
| `elk`        | ELK stack            | `elastic_password`, `kibana_password`                                                                                        |
| `synology`   | Synology NAS         | `username`, `password`                                                                                                       |
| `youtube`    | YouTube API          | `client_id`, `client_secret`, `access_token`, `refresh_token`                                                               |
| `telegram`   | Telegram Bot API     | `bot_token`                                                                                                                 |
| `pbs`        | Proxmox Backup       | `username`, `password` (optional, gated by `enable_pbs`)                                                                     |

**Module outputs:**

- 23 secret keys (sensitive=true, not printed in Terraform output)
- 11 metadata keys (sensitive=false)

**Access pattern:**

```hcl
# Simplified (preferred)
module.secrets.secrets["elk_elastic_password"]

# Verbose with fallback
try(module.secrets.secrets["elk_elastic_password"], section_map["Passwords"].field_map["elastic_password"].value, "")
```

## Workspace Integration

| Workspace             | Has onepassword.tf       | Key Secrets Consumed                               |
| --------------------- | ------------------------ | -------------------------------------------------- |
| 100-pve               | via versions.tf provider | `proxmox_api_token`, all template secrets          |
| 105-elk/terraform     | ✅                       | `elk_elastic_password`                             |
| 215-synology          | ✅                       | `synology_username`, `synology_password`           |
| 300-cloudflare        | ✅                       | Cloudflare account/zone IDs, API token/key fallback, Google OAuth |

## Runtime Secret Distribution

Per-host `.env` secrets deployed via config-renderer templates:

| Host          | Secrets                                                                                                                                    |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| cliproxy (VMID 114) | `homelab_tunnel_token` (native cloudflared systemd service)                                                                            |
| 105-elk       | `elastic_password`, `kibana_password` (in docker-compose env vars)                                                                         |

## Provider Authentication

The Terraform provider authenticates to 1Password with a service-account token.

**Local Terraform runs:** Set `OP_SERVICE_ACCOUNT_TOKEN` or pass the `op_service_account_token` variable:

```bash
export OP_SERVICE_ACCOUNT_TOKEN="ops_..."
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

# Access: module.secrets.secrets["elk_elastic_password"]
```

## Secret Inventory (GitHub Actions)

### 1Password-Sourced (via `sync-vault-secrets.go`)

| Secret                | 1Password Reference                                  | Field                   | Priority |
| --------------------- | ---------------------------------------------------- | ----------------------- | -------- |
| `GH_PAT`              | `op://homelab/github/secrets/personal_access_token`  | `personal_access_token` | P2       |

### From local `.tfvars` (via `setup-github-secrets.go`)

| Secret                         | Source File                       | Variable                | Priority |
| ------------------------------ | --------------------------------- | ----------------------- | -------- |
| `TF_VAR_PROXMOX_ENDPOINT`      | `100-pve/terraform/terraform.tfvars`        | `proxmox_endpoint`      | P0       |
| `TF_VAR_PROXMOX_API_TOKEN`    | `100-pve/terraform/terraform.tfvars`        | `proxmox_api_token`     | P0       |
| `TF_VAR_PROXMOX_INSECURE`     | `100-pve/terraform/terraform.tfvars`        | `proxmox_insecure`      | P0       |
| `TF_VAR_CLOUDFLARE_ACCOUNT_ID`| `300-cloudflare/terraform/terraform.tfvars` | `cloudflare_account_id` | P1       |
| `TF_VAR_CLOUDFLARE_ZONE_ID`   | `300-cloudflare/terraform/terraform.tfvars` | `cloudflare_zone_id`    | P1       |
| `TF_VAR_SYNOLOGY_DOMAIN`      | `300-cloudflare/terraform/terraform.tfvars` | `synology_domain`       | P1       |
| `CLOUDFLARE_API_TOKEN`        | env / CF dashboard                | —                       | P2       |

Note: `PROXMOX_ENDPOINT` was renamed to `TF_VAR_PROXMOX_ENDPOINT` and all workflow references now use the canonical `TF_VAR_*` secret name.

### Manual (3/17 — not in 1Password)

| Secret                    | Priority | Source                                  | Used By                     |
| ------------------------- | -------- | --------------------------------------- | --------------------------- |
| `TF_API_TOKEN`            | P0       | Terraform Cloud (skip if not using TFC) | terraform-plan/apply, drift |

## Secret Rotation

```bash
# 1. Update value in 1Password
#    Via UI: 1Password → homelab vault → item → Edit field
#    Via CLI: op item edit "cloudflare" "secrets.account_id=NEW" --vault homelab

# 2. Push to GitHub
go run scripts/sync-vault-secrets.go --force

# 3. Verify
go run scripts/setup-github-secrets.go --audit
```

## Weekly Audit

The `secret-audit.yml` workflow runs every Monday at 09:00 UTC.
It validates all 17 secrets and reports missing ones.
Trigger manually: Actions → Secret Audit → Run workflow.

## Cross-References

- [Cloudflare Token Rotation](cloudflare-token-rotation.md)
- [Credential Rotation Runbook](runbooks/credential-rotation.md)
