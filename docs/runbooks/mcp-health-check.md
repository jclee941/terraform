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

| Server      | Transport           | Status (2026-03-28)        | Fix Section                             |
| ----------- | ------------------- | -------------------------- | --------------------------------------- |
| elk         | stdio               | ✅ Connected               | —                                       |
| kratos      | stdio               | ✅ Connected               | —                                       |
| terraform   | stdio               | ✅ Connected               | —                                       |
| github      | stdio               | ✅ Connected               | —                                       |
| git         | stdio               | ✅ Connected               | —                                       |
| onepassword | stdio               | ✅ Connected               | [1Password](#1password-empty-vault)     |
| **archon**  | **streamable-http** | ✅ Connected (native HTTP) | [Archon](#archon-streamable-http)       |
| proxmox     | sse                 | ✅ Connected               | —                                       |
| playwright  | sse                 | ✅ Connected               | —                                       |
| **n8n**     | **streamable-http** | ✅ Connected               | —                                       |
| supabase    | stdio               | ⏳ Pending (new)           | —                                       |

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

Expected: `✅ Catalog valid: 13 servers (hub=13, local=0, external=0)`

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


### Archon: Streamable HTTP

**Transport:** `streamable-http` (native MCPHub support, no bridge)

Archon runs on LXC 108:8051 using Streamable HTTP transport. MCPHub connects directly via its native `streamable-http` transport type — no `mcp-remote` bridge needed.

**Verify archon server is healthy:**

```bash
# From any network host
curl -sf http://192.168.50.108:8051/health | jq .
# Expected: {"success":true,"status":"ready","uptime_seconds":...}
```

**Verify MCPHub connection:**

```bash
curl -sf http://192.168.50.112:3000/api/servers | jq '.data[] | select(.name == "archon") | {name, status}'
# Expected: {"name":"archon","status":"connected"}
```

**If archon shows disconnected:**

1. Confirm archon server is running: `curl -sf http://192.168.50.108:8051/health`
2. Check MCPHub logs: `docker logs mcphub 2>&1 | grep -i archon | tail -20`
3. Verify `mcp_servers.json` has `"transport": "streamable-http"` and `"url": "http://192.168.50.108:8051/mcp"`
4. Restart MCPHub: `docker restart mcphub && sleep 15`
5. Re-check: `curl -sf http://192.168.50.112:3000/api/servers | jq '.data[] | select(.name == "archon")'`
---

## Prevention

1. **Scheduled monitoring:** `terraform-drift.yml` runs Mon-Fri 00:00 UTC and catches state drift across all 7 workspaces.
2. **Catalog validation:** Run `python3 112-mcphub/validate_mcps.py` before any MCPHub config change.
3. **Credential rotation:** Follow `docs/runbooks/credential-rotation.md` for scheduled token renewal.
4. **1Password CI test:** `onepassword-test.yml` runs on PR, `workflow_dispatch`, and after `mcp-health-check.yml` to verify vault connectivity and all 12 expected items.
5. **Health check workflow:** `.github/workflows/mcp-health-check.yml` checks MCPHub gateway health and per-server status via the MCPHub API on port 3000. Runs Mon-Fri 01:00 UTC.
