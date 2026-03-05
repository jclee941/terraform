# Credential Rotation

Scheduled and reactive rotation procedures for homelab service credentials.

## Symptoms
- Authentication failures in service logs
- n8n workflows failing with 401/403
- MCP connections dropping
- GlitchTip not receiving events
- `onepassword-test.yml` or `mcp-health-check.yml` reporting auth failures

## Credential Inventory

| Credential | Location | Cadence | Service |
|------------|----------|---------|---------|
| 1Password SA Token | GitHub secret + MCPHub `.env` | 90 days / on failure | CI + MCPHub |
| Cloudflare API Token | GitHub secret | 90 days / on failure | Cloudflare CI |
| GitHub PAT | GitHub secret + 1Password | 90 days / on failure | CI cross-repo |
| n8n MCP API Key | `/opt/mcphub/.env` on VM 112 | 2026-05-11 | MCPHub |
| GlitchTip API Token | `/opt/glitchtip/.env` on LXC 106 | On failure | GlitchTip |
| GitHub Runner Token | `/opt/runner/.env` on LXC 101 | 30 days | GitHub Actions |
| Synology credentials | 1Password synology item | On failure | Synology NAS |
| Slack bot/app tokens | 1Password slack item | On failure | Slack |
| YouTube OAuth tokens | 1Password youtube item | On failure | YouTube |
| CF Access service token | access.tf (time_rotating) | 60 days | Cloudflare Access |

---

## 1Password Service Account Token

**Scope:** GitHub Actions CI + MCPHub (192.168.50.112)

```bash
# 1. Generate new token
#    1Password admin → Service Accounts → homelab → Rotate Token

# 2. Update GitHub Actions secrets (Connect Server auth)
gh secret set OP_CONNECT_TOKEN
gh secret set OP_CONNECT_HOST

# 3. Update MCPHub .env
pct exec 112 -- sed -i 's|OP_SERVICE_ACCOUNT_TOKEN=.*|OP_SERVICE_ACCOUNT_TOKEN=<new-token>|' /opt/mcphub/.env

# 4. Restart MCPHub 1Password server
pct exec 112 -- docker compose -f /opt/mcphub/docker-compose.yml restart

# 5. Verify
#    Run onepassword-test.yml via workflow_dispatch
#    Check: op whoami, op vault list, 12 items accessible
```

**Verification:**
- `onepassword-test.yml` (workflow_dispatch) validates token + vault + 12 items + critical fields.
- `mcp-health-check.yml` includes 1Password smoke test (op whoami + vault list).

---

## Cloudflare API Token

See `docs/cloudflare-token-rotation.md` for full procedure.

**Scope:** `CLOUDFLARE_API_TOKEN` GitHub secret
**Required permissions:** Zone:DNS:Edit, Zone:Zone:Read, Account:Workers:Edit, Account:R2:Edit

```bash
# After generating new token at CF dashboard:
gh secret set CLOUDFLARE_API_TOKEN
# Re-run failed cloudflare-apply or worker-deploy workflow
```

---

## GlitchTip API Token

**Scope:** MCPHub GlitchTip MCP server (192.168.50.112:8075) + n8n webhook

```bash
# 1. Get new token from GlitchTip UI (glitchtip.jclee.me)
#    Org: jclee-homelab → Settings → API Tokens → Create
# 2. Update 1Password: op://homelab/glitchtip/api_token
# 3. Update MCPHub .env
pct exec 112 -- sed -i 's|GLITCHTIP_AUTH_TOKEN=.*|GLITCHTIP_AUTH_TOKEN=<new-token>|' /opt/mcphub/.env
# 4. Update n8n workflow webhook credential
#    n8n UI (192.168.50.112:5678) → Credentials → GlitchTip API → Update token
# 5. Restart
pct exec 112 -- docker compose -f /opt/mcphub/docker-compose.yml restart
# 6. Verify
curl -s -H "Authorization: Bearer <token>" http://192.168.50.106:8000/api/0/organizations/
curl http://192.168.50.112:8075/health
```

---

## GitHub PAT

**Scope:** `GH_PAT` GitHub secret + 1Password

```bash
# 1. Generate new token: GitHub → Settings → Personal Access Tokens → Fine-grained
# 2. Update 1Password: op://homelab/github/personal_access_token
# 3. Sync to GitHub Actions:
scripts/sync-vault-secrets.sh --force
# 4. Verify: gh auth status
```

---

## n8n MCP API Key

**Scope:** MCPHub API authentication
**Expiry:** 2026-05-11

```bash
# 1. Generate new key in MCPHub UI (mcphub.jclee.me)
#    Login: admin → Settings → API Keys → Create
# 2. Update on VM 112
pct exec 112 -- vim /opt/mcphub/.env  # Update MCP_API_KEY=<new-key>
# 3. Restart services
pct exec 112 -- docker compose -f /opt/mcphub/docker-compose.yml restart
pct exec 112 -- docker compose -f /opt/n8n/docker-compose.yml restart
# 4. Verify
curl -s -H "Authorization: Bearer <new-key>" http://192.168.50.112:3000/api/health
```

---

## GitHub Actions Runner Token

**Scope:** Self-hosted runner on LXC 101
**Cadence:** 30 days

```bash
# 1. Generate new token at GitHub repo Settings → Actions → Runners
# 2. Update on LXC 101
pct exec 101 -- bash -c '
  cd /opt/runner
  ./config.sh remove --token <old-token>
  ./config.sh --url https://github.com/jclee-homelab/proxmox --token <new-token>
  systemctl restart actions-runner
'
```

---

## Synology Credentials

**Scope:** Synology NAS API access (1Password synology item)

```bash
# 1. Get credentials from 1Password
#    op://homelab/synology/username
#    op://homelab/synology/password
# 2. Update any services using Synology credentials
# 3. Verify
curl -u <user>:<pass> https://<synology-ip>/webapi/auth.cgi?api=SYNO.API.Auth&version=3&method=login&account=<user>&passwd=<pass>
```

---

## Slack Bot/App Tokens

**Scope:** Slack API access for 320-slack workspace

```bash
# 1. Get token from 1Password
#    op://homelab/slack/bot_token
#    op://homelab/slack/app_token
# 2. Update GitHub secret
gh secret set SLACK_BOT_TOKEN
gh secret set SLACK_APP_TOKEN
# 3. Re-run slack-apply workflow
```

---

## YouTube OAuth Tokens

**Scope:** YouTube Data API access (220-youtube workspace)

```bash
# 1. Refresh OAuth tokens in Google Cloud Console
#    https://console.cloud.google.com/apis/credentials
# 2. Update 1Password
op item edit "youtube" "secrets.client_secret=NEW" --vault homelab
# 3. Re-run youtube-apply if needed
```

---

## Cloudflare Access Service Token

**Scope:** Cloudflare Zero Trust internal service access
**Cadence:** 60 days (managed via terraform time_rotating in access.tf)

```bash
# 1. Token auto-rotates via terraform time_rotating resource
# 2. Verify current token is valid
curl -H "Authorization: Bearer $(op item get youtube --fields secrets.access_token)" https://internal-service.jclee.me
# 3. If rotation needed, re-run terraform apply in 300-cloudflare
```

---

## Rotation Audit

```bash
# Audit 1Password → GitHub sync status
scripts/sync-vault-secrets.sh --audit

# Full secret inventory audit
scripts/setup-github-secrets.sh --audit
```

## Prevention

- Set calendar reminders 2 weeks before expiry.
- Monitor auth failures in Grafana/ELK dashboards.
- n8n MCP API key expiry: **2026-05-11** — rotate before then.

**Cross-reference:** `docs/secret-management.md` for full secret architecture.
