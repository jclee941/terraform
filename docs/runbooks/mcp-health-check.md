# MCP Service Health Check Runbook

**Last verified:** 2026-02-23
**Host:** LXC 112 (192.168.50.112) — MCPHub gateway
**Catalog SSoT:** `112-mcphub/mcp_servers.json`

## Quick Reference

| Service            | Port     | Status (2026-02-23)        | Fix Section                             |
| ------------------ | -------- | -------------------------- | --------------------------------------- |
| ELK                | 8065     | ✅ Healthy (GREEN)         | —                                       |
| Kratos             | 8060     | ✅ Healthy (v4.0.0)        | —                                       |
| Terraform Registry | 8071     | ✅ Healthy                 | —                                       |
| GitHub             | 8058     | ✅ Healthy                 | —                                       |
| Git                | 8059     | ✅ Healthy                 | —                                       |
| **1Password**      | **8077** | **🔴 Empty vault**         | [1Password](#1password-empty-vault)     |
| **Supabase**       | **8076** | **🔴 Auth failure**        | [Supabase](#supabase-db-auth-failure)   |
| **GlitchTip**      | **8075** | **🔴 Unreachable**         | [GlitchTip](#glitchtip-api-unreachable) |
| Archon             | 8078     | 🟡 Partial (agents opt-in) | [Archon](#archon-agents-service-false)  |
| Slack              | 8079     | ⚪ Not tested              | —                                       |

## Diagnosis

### Full health sweep from MCPHub host

```bash
# SSH into MCPHub
ssh root@192.168.50.112

# Check all MCP server containers
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep mcp

# Check individual service ports
for port in 8058 8059 8060 8065 8071 8075 8076 8077 8078 8079; do
  echo -n "Port $port: "
  curl -sf -o /dev/null -w "%{http_code}" http://localhost:$port/health 2>/dev/null || echo "UNREACHABLE"
done
```

### Validate catalog schema

```bash
cd /path/to/terraform
python3 112-mcphub/validate_mcps.py
```

Expected: `10/10 servers valid`

---

## Resolution

### 1Password: Empty Vault

**Symptom:** `vault_list` returns `{"vaults": []}`. All 12 item lookups in Terraform return empty strings.

**Root cause:** `OP_SERVICE_ACCOUNT_TOKEN` expired or vault permissions revoked.

**Fix:**

```bash
# 1. Verify current token on MCPHub host
ssh root@192.168.50.112
cat /opt/mcphub/.env | grep OP_SERVICE_ACCOUNT_TOKEN

# 2. Test token directly
export OP_SERVICE_ACCOUNT_TOKEN="<token from .env>"
# Install op CLI if needed: https://developer.1password.com/docs/cli/get-started/
op vault list --format=json

# Expected: list of vaults including "Homelab"
# If empty or error: token is invalid/expired
```

**Token rotation (if expired):**

```bash
# 3. Generate new token in 1Password console:
#    https://my.1password.com → Settings → Service Accounts
#    - Select the service account used for MCPHub
#    - Generate new token
#    - Ensure "Homelab" vault is in permissions

# 4. Update token on MCPHub host
ssh root@192.168.50.112
# Edit .env file with new token
nano /opt/mcphub/.env
# Update: OP_SERVICE_ACCOUNT_TOKEN=<new-token>

# 5. Restart 1Password MCP server
docker restart mcphub-onepassword

# 6. Verify
curl -s http://localhost:8077/health
```

**Verify in Terraform:**

```bash
cd /path/to/terraform
terraform -chdir=100-pve plan -target=module.onepassword_secrets 2>&1 | grep -c "Read complete"
# Expected: 12 (one per item)
```

**Also update GitHub secret:**

```bash
# If token changed, update GHA secret too
gh secret set OP_SERVICE_ACCOUNT_TOKEN -R qws941/terraform
```

---

### Supabase: DB Auth Failure

**Symptom:** `password authentication failed for user "supabase_read_only_user"`.

**Root cause:** MCP server configured with `supabase_read_only_user` role, but this role was never created in the Supabase PostgreSQL database. The database only has `supabase_admin` and `authenticator` roles (per `.env.tftpl`).

**Fix:**

```bash
# 1. SSH into Supabase LXC
ssh root@192.168.50.107
# Or from Proxmox:
pct exec 107 -- bash

# 2. Connect to PostgreSQL
docker exec -it supabase-db psql -U supabase_admin -d postgres

# 3. Create read-only role
CREATE ROLE supabase_read_only_user WITH LOGIN PASSWORD '<generate-secure-password>';
GRANT CONNECT ON DATABASE postgres TO supabase_read_only_user;
GRANT USAGE ON SCHEMA public TO supabase_read_only_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO supabase_read_only_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO supabase_read_only_user;

-- Also grant on supabase-specific schemas
GRANT USAGE ON SCHEMA auth TO supabase_read_only_user;
GRANT SELECT ON ALL TABLES IN SCHEMA auth TO supabase_read_only_user;
GRANT USAGE ON SCHEMA storage TO supabase_read_only_user;
GRANT SELECT ON ALL TABLES IN SCHEMA storage TO supabase_read_only_user;

\q

# 4. Update MCP server env with the password
ssh root@192.168.50.112
nano /opt/mcphub/.env
# Update SUPABASE connection string with new password

# 5. Restart Supabase MCP server
docker restart mcphub-supabase

# 6. Verify
curl -s http://localhost:8076/health
```

**Store password in 1Password:**

After 1Password is fixed, store the `supabase_read_only_user` password in the Homelab vault under the `supabase` item.

---

### GlitchTip: API Unreachable

**Symptom:** `Resource not found` from MCP server.

**Root cause:** One of: (a) `GLITCHTIP_BASE_URL` misconfigured, (b) `GLITCHTIP_TOKEN` invalid, (c) `GLITCHTIP_ORG` slug mismatch.

**Fix:**

```bash
# 1. Verify GlitchTip is running
ssh root@192.168.50.106
# Or: pct exec 106 -- bash
docker ps | grep glitchtip
curl -sf http://localhost:8000/api/0/organizations/ && echo "API OK" || echo "API DOWN"

# 2. If API is up, check token
ssh root@192.168.50.112
cat /opt/mcphub/.env | grep GLITCHTIP

# Expected env vars:
# GLITCHTIP_BASE_URL=http://192.168.50.106:8000
# GLITCHTIP_TOKEN=<api-token>
# GLITCHTIP_ORG=<org-slug>

# 3. Test token directly
curl -H "Authorization: Bearer <token>" \
  http://192.168.50.106:8000/api/0/organizations/

# If 401: token expired — regenerate in GlitchTip UI
# If 404: org slug wrong — list orgs to find correct slug:
curl -H "Authorization: Bearer <token>" \
  http://192.168.50.106:8000/api/0/organizations/

# 4. Regenerate token if needed:
#    Open http://192.168.50.106:8000 → Settings → API Keys → Create

# 5. Update env and restart
ssh root@192.168.50.112
nano /opt/mcphub/.env
docker restart mcphub-glitchtip

# 6. Verify
curl -s http://localhost:8075/health
```

**Cross-reference:** See `docs/runbooks/credential-rotation.md` for GlitchTip token rotation procedure.

---

### Archon: agents_service=FALSE

**Symptom:** Health check shows `agents_service: false`.

**Root cause:** This is **expected behavior**. The Archon `agents` service runs under a Docker Compose profile (`profile: agents`) that is opt-in. It is not started by default.

**No action required** unless agent functionality is needed.

**To enable agents (optional):**

```bash
ssh root@192.168.50.108
# Or: pct exec 108 -- bash
cd /opt/archon
docker compose --profile agents up -d
```

---

## Prevention

1. **Scheduled monitoring:** `terraform-drift.yml` runs Mon-Fri 00:00 UTC and catches state drift across all 7 workspaces.
2. **Catalog validation:** Run `python3 112-mcphub/validate_mcps.py` before any MCPHub config change.
3. **Credential rotation:** Follow `docs/runbooks/credential-rotation.md` for scheduled token renewal.
4. **1Password CI test:** `onepassword-test.yml` runs on PR to verify vault connectivity and all 12 expected items.
5. **Health check workflow:** `.github/workflows/mcp-health-check.yml` provides on-demand MCP service verification.
