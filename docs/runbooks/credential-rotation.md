# Credential Rotation

Scheduled and reactive rotation procedures for homelab service credentials.

## Symptoms
- Authentication failures in service logs
- MCP connections dropping
- `onepassword-test.yml` or `mcp-health-check.yml` reporting auth failures

## Credential Inventory

| Credential | Location | Cadence | Service |
|------------|----------|---------|---------|
| 1Password SA Token | GitHub secret + MCPHub `.env` | 90 days / on failure | CI + MCPHub |
| Cloudflare API Token | GitHub secret | 90 days / on failure | Cloudflare CI |
| GitHub PAT | GitHub secret + 1Password | 90 days / on failure | CI cross-repo |
| GitHub Runner Token | `/opt/runner/.env` on LXC 101 | 30 days | GitHub Actions |
| Synology credentials | 1Password synology item | On failure | Synology NAS |
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

## GitHub PAT

**Scope:** `GH_PAT` GitHub secret + 1Password

```bash
# 1. Generate new token: GitHub → Settings → Personal Access Tokens → Fine-grained
# 2. Update 1Password: op://homelab/github/personal_access_token
# 3. Sync to GitHub Actions:
go run scripts/sync-vault-secrets.go --force
# 4. Verify: gh auth status
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
go run scripts/sync-vault-secrets.go --audit

# Full secret inventory audit
go run scripts/setup-github-secrets.go --audit
```

## Prevention

- Set calendar reminders 2 weeks before expiry.
- Monitor auth failures in ELK dashboards and the current alerting pipeline.
**Cross-reference:** `docs/secret-management.md` for full secret architecture.
