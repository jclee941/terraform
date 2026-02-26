# MCP Service Health Check Runbook

**Last verified:** 2026-02-26
**Host:** LXC 112 (192.168.50.112) — MCPHub gateway
**Catalog SSoT:** `112-mcphub/mcp_servers.json`

## Architecture

MCPHub runs as a **single Docker container** (`mcphub`) on LXC 112, listening on **port 3000**.
All MCP servers are **STDIO child processes** inside the MCPHub container — they do NOT listen on individual network ports.

| Component          | Endpoint                                 | Notes                                        |
| ------------------ | ---------------------------------------- | -------------------------------------------- |
| Gateway health     | `http://192.168.50.112:3000/health`      | Returns `{"status":"healthy"}` when all OK   |
| Per-server status  | `http://192.168.50.112:3000/api/servers` | JSON array with name, status, enabled fields |
| Catalog validation | `python3 112-mcphub/validate_mcps.py`    | Validates `mcp_servers.json` schema          |

## Quick Reference

| Server      | Transport | Status (2026-02-26)      | Fix Section                             |
| ----------- | --------- | ------------------------ | --------------------------------------- |
| elk         | stdio     | ✅ Connected             | —                                       |
| kratos      | stdio     | ✅ Connected             | —                                       |
| terraform   | stdio     | ✅ Connected             | —                                       |
| github      | stdio     | ✅ Connected             | —                                       |
| git         | stdio     | ✅ Connected             | —                                       |
| onepassword | stdio     | ✅ Connected             | [1Password](#1password-empty-vault)     |
| supabase    | stdio     | ✅ Connected             | [Supabase](#supabase-db-auth-failure)   |
| glitchtip   | stdio     | ✅ Connected             | [GlitchTip](#glitchtip-api-unreachable) |
| **archon**  | **stdio** | **🔴 Connection closed** | [Archon](#archon-mcp-remote-bridge)     |
| slack       | stdio     | ✅ Connected             | —                                       |
| proxmox     | stdio     | ✅ Connected             | —                                       |
| playwright  | stdio     | ✅ Connected             | —                                       |

## Diagnosis

### Gateway health check

```bash
# From any host on the network
curl -sf http://192.168.50.112:3000/health | jq .
# Expected: {"status":"healthy","message":"All enabled MCP servers are ready"}
# Unhealthy: {"status":"unhealthy","message":"Not all enabled MCP servers are ready"}
```

### Per-server status

```bash
curl -sf http://192.168.50.112:3000/api/servers | jq '[.data[] | {name, status, enabled}]'
# Each server: status="connected" means healthy
# Any other status (disconnected, error, etc.) = failed
```

### MCPHub container health

```bash
ssh root@192.168.50.112

# Check container is running
docker ps --filter name=mcphub --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# View recent logs
docker logs mcphub --tail 50

# View logs for a specific server failure
docker logs mcphub 2>&1 | grep -i "archon\|error\|fail" | tail -20
```

### Validate catalog schema

```bash
cd /path/to/terraform
python3 112-mcphub/validate_mcps.py
```

Expected: `✅ Catalog valid: 12 servers (hub=12, local=0, external=0)`

---

### MCP workspace path visibility check (Git/Kratos path mismatch)

**Symptom:** MCP calls fail with `Directory does not exist` even though the path exists on your local shell.

**Root cause:** MCPHub runs in a container and resolves filesystem paths inside container namespace. Host-only paths are not directly visible unless bind-mounted.

**Standardized paths (as of 2026-02-23):**

- Host path: `${MCP_WORKSPACE_HOST_PATH}` (default `/home/jclee/dev`)
- Container path: `${MCP_WORKSPACE_CONTAINER_PATH}` (default `/workspace/dev`)
- Compatibility alias: host path is also mounted to `/home/jclee/dev`

**Verify mount visibility on MCPHub host:**

```bash
ssh root@192.168.50.112
cd /opt/mcphub
docker compose exec mcphub sh -lc 'ls -ld /workspace/dev /home/jclee/dev'
docker compose exec mcphub sh -lc 'test -d /workspace/dev/terraform && echo OK || echo MISSING'
```

**Fix (if missing):**

```bash
ssh root@192.168.50.112
cd /opt/mcphub

# Ensure .env has:
# MCP_WORKSPACE_HOST_PATH=/home/jclee/dev
# MCP_WORKSPACE_CONTAINER_PATH=/workspace/dev

docker compose up -d
docker compose exec mcphub sh -lc 'test -d /workspace/dev/terraform && echo OK || echo MISSING'
```

**Usage guidance:** Prefer `/workspace/dev/terraform` for MCP calls in containerized contexts.

---

## Resolution

### Restart MCPHub (all servers)

All MCP servers restart together since they are child processes of the single MCPHub container:

```bash
ssh root@192.168.50.112
docker restart mcphub

# Wait 10-15 seconds for servers to reconnect, then verify
sleep 15
curl -sf http://192.168.50.112:3000/health | jq .
curl -sf http://192.168.50.112:3000/api/servers | jq '[.data[] | {name, status}]'
```

### 1Password: Empty Vault

**Symptom:** `vault_list` returns `{"vaults": []}`. All 12 item lookups in Terraform return empty strings.

**Root cause:** `OP_SERVICE_ACCOUNT_TOKEN` expired or vault permissions revoked.

**Fix:**

```bash
# 1. Check 1Password status via MCPHub API
curl -sf http://192.168.50.112:3000/api/servers | jq '.data[] | select(.name == "onepassword")'

# 2. Verify current token on MCPHub host
ssh root@192.168.50.112
cat /opt/mcphub/.env | grep OP_SERVICE_ACCOUNT_TOKEN

# 3. Test token directly
export OP_SERVICE_ACCOUNT_TOKEN="<token from .env>"
# Install op CLI if needed: https://developer.1password.com/docs/cli/get-started/
op vault list --format=json

# Expected: list of vaults including "Homelab"
# If empty or error: token is invalid/expired
```

**Token rotation (if expired):**

```bash
# 4. Generate new token in 1Password console:
#    https://my.1password.com → Settings → Service Accounts
#    - Select the service account used for MCPHub
#    - Generate new token
#    - Ensure "Homelab" vault is in permissions

# 5. Update token on MCPHub host
ssh root@192.168.50.112
nano /opt/mcphub/.env
# Update: OP_SERVICE_ACCOUNT_TOKEN=<new-token>

# 6. Restart MCPHub (restarts all MCP servers including 1Password)
docker restart mcphub

# 7. Verify
sleep 15
curl -sf http://192.168.50.112:3000/api/servers | jq '.data[] | select(.name == "onepassword") | {name, status}'
```

**Verify in Terraform:**

```bash
cd /path/to/terraform
terraform -chdir=100-pve plan -target=module.onepassword_secrets 2>&1 | grep -c "Read complete"
# Expected: 12 (one per item)
```

**Also update GitHub secret:**

```bash
# If token changed, update GHA secrets too
gh secret set OP_CONNECT_TOKEN
gh secret set OP_CONNECT_HOST
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

# 5. Restart MCPHub
docker restart mcphub

# 6. Verify
sleep 15
curl -sf http://192.168.50.112:3000/api/servers | jq '.data[] | select(.name == "supabase") | {name, status}'
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
# If 404: org slug wrong — list orgs to find correct slug

# 4. Regenerate token if needed:
#    Open http://192.168.50.106:8000 → Settings → API Keys → Create

# 5. Update env and restart
ssh root@192.168.50.112
nano /opt/mcphub/.env
docker restart mcphub

# 6. Verify
sleep 15
curl -sf http://192.168.50.112:3000/api/servers | jq '.data[] | select(.name == "glitchtip") | {name, status}'
```

**Cross-reference:** See `docs/runbooks/credential-rotation.md` for GlitchTip token rotation procedure.

---

### Archon: mcp-remote Bridge

**Symptom:** MCPHub reports `MCP error -32000: Connection closed` for archon.

**Root cause:** Archon is the **only** MCP server that uses `mcp-remote` as an HTTP-to-STDIO bridge (all other servers are pure STDIO). The `npx -y mcp-remote` child process crashes inside the MCPHub Docker container, likely due to missing dependencies, npm cache issues, or Node.js version mismatch within the container environment.

**Architecture:**

- Archon MCP server runs on LXC 108:8051 (Streamable HTTP transport)
- MCPHub config spawns `npx -y mcp-remote http://192.168.50.108:8051/mcp --allow-http --transport http-only` as STDIO child
- The `mcp-remote` process fails inside the container despite working from the host

**Verify archon server is healthy:**

```bash
# From MCPHub host or any network host
curl -sf http://192.168.50.108:8051/health | jq .
# Expected: {"success":true,"status":"ready","uptime_seconds":...}
```

**Debug mcp-remote inside container:**

```bash
ssh root@192.168.50.112
cd /opt/mcphub

# Check if mcp-remote can resolve inside container
docker compose exec mcphub npx -y mcp-remote --version

# Check network connectivity from container to archon
docker compose exec mcphub curl -sf http://192.168.50.108:8051/health

# Check MCPHub logs for archon-specific errors
docker logs mcphub 2>&1 | grep -i archon | tail -20
```

**Fix options:**

1. **Pre-install mcp-remote** in the MCPHub Docker image (add to `package.json` or Dockerfile)
2. **Use MCPHub's native HTTP transport** if supported — check MCPHub docs for `transport: "http"` or `transport: "streamable-http"` config
3. **Switch archon to SSE transport** and configure MCPHub accordingly

**No action required** if archon functionality is not actively used. The other 11 servers remain unaffected.

---

## Prevention

1. **Scheduled monitoring:** `terraform-drift.yml` runs Mon-Fri 00:00 UTC and catches state drift across all 7 workspaces.
2. **Catalog validation:** Run `python3 112-mcphub/validate_mcps.py` before any MCPHub config change.
3. **Credential rotation:** Follow `docs/runbooks/credential-rotation.md` for scheduled token renewal.
4. **1Password CI test:** `onepassword-test.yml` runs on PR, `workflow_dispatch`, and after `mcp-health-check.yml` to verify vault connectivity and all 12 expected items.
5. **Health check workflow:** `.github/workflows/mcp-health-check.yml` checks MCPHub gateway health and per-server status via the MCPHub API on port 3000. Runs Mon-Fri 01:00 UTC.
