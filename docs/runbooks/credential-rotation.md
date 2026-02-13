# Token/Credential Rotation

## Symptoms
- Authentication failures in service logs
- n8n workflows failing with 401/403
- MCP connections dropping
- GlitchTip not receiving events

## Credential Inventory

| Credential | Location | Expiry | Service |
|-----------|----------|--------|---------|
| n8n MCP API Key | `/opt/mcphub/.env` on VM 112 | 2026-05-11 | MCPHub |
| GlitchTip API Token | `/opt/glitchtip/.env` on LXC 106 | No expiry | GlitchTip |
| Vault Token | `http://192.168.50.112:8200` | Periodic | Vault Agent |
| GitHub Runner Token | `/opt/runner/.env` on LXC 101 | 30 days | GitHub Actions |

## Resolution

### n8n MCP API Key Rotation
```bash
# 1. Generate new key in MCPHub UI (mcphub.jclee.me)
#    Login: admin/admin123 → Settings → API Keys → Create

# 2. Update on VM 112
ssh root@192.168.50.112
vim /opt/mcphub/.env  # Update MCP_API_KEY=<new-key>

# 3. Restart services
docker compose -f /opt/mcphub/docker-compose.yml restart
docker compose -f /opt/n8n/docker-compose.yml restart

# 4. Verify
curl -s -H "Authorization: Bearer <new-key>" http://192.168.50.112:3000/api/health
```

### GlitchTip API Token Rotation
```bash
# 1. Generate new token in GlitchTip UI (glitchtip.jclee.me)
#    Org: jclee-homelab → Settings → API Tokens → Create

# 2. Update n8n workflow webhook credential
#    n8n UI (192.168.50.112:5678) → Credentials → GlitchTip API → Update token

# 3. Verify
curl -s -H "Authorization: Bearer <token>" \
  http://192.168.50.106:8000/api/0/organizations/
```

### Vault Token Rotation
```bash
# Vault Agent on VM 112 handles auto-renewal
# Manual rotation only if agent fails:

export VAULT_ADDR="http://192.168.50.112:8200"

# 1. Login with root token
vault login <root-token>

# 2. Create new periodic token
vault token create -period=768h -policy=default

# 3. Update Vault Agent config
ssh root@192.168.50.112
vim /etc/vault-agent/config.hcl  # Update token
systemctl restart vault-agent
```

### GitHub Actions Runner Token
```bash
# 1. Generate new token at GitHub repo Settings → Actions → Runners
# 2. Update on LXC 101
ssh pve
pct exec 101 -- bash -c '
  cd /opt/runner
  ./config.sh remove --token <old-token>
  ./config.sh --url https://github.com/jclee-homelab/proxmox --token <new-token>
  systemctl restart actions-runner
'
```

## Prevention
- Set calendar reminders 2 weeks before expiry
- Vault Agent auto-renews periodic tokens
- Monitor auth failures in Grafana/ELK dashboards
- n8n MCP API key expiry: **2026-05-11** — rotate before then
