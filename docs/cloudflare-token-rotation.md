# Cloudflare Service Token Rotation Guide

## Overview

This document describes the procedure for rotating Cloudflare Access Service Tokens used by GitHub Actions to access internal homelab services via Cloudflare Tunnel.

## Current Token

| Property | Value |
|----------|-------|
| **Name** | `github-actions-ci` |
| **Created** | 2026-02-04 |
| **Expires** | 2027-02-04 (1 year) |
| **Used By** | GitHub Actions workflows accessing internal services |
| **GitHub Secrets** | `CF_ACCESS_CLIENT_ID`, `CF_ACCESS_CLIENT_SECRET` |

## Protected Services

The following services are accessible via the Cloudflare Tunnel with this token:

| Service | Subdomain | Backend |
|---------|-----------|---------|
| Traefik API | `traefik-api.jclee.me` | 192.168.50.102:8080 |
| Grafana | `grafana.jclee.me` | 192.168.50.104:3000 |
| MCPHub | `mcphub.jclee.me` | 192.168.50.112:3000 |
| Archon | `archon.jclee.me` | 192.168.50.108:80 |
| Kibana | `kibana.jclee.me` | 192.168.50.105:5601 |
| n8n | `n8n.jclee.me` | 192.168.50.112:5678 |
| Supabase | `supabase.jclee.me` | 192.168.50.107:8000 |

## Rotation Procedure (Zero Downtime)

### Prerequisites

- Cloudflare Zero Trust dashboard access
- GitHub repository admin access (`jclee-homelab/proxmox`)

### Step 1: Create New Token (Keep Old Active)

1. Navigate to: [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Go to: **Access** → **Service Auth** → **Service Tokens**
3. Click **"Create Service Token"**
4. Configure:
   - **Name**: `github-actions-ci-v2` (increment version number)
   - **Duration**: 1 year
5. Click **"Generate Token"**
6. **CRITICAL**: Copy both `Client ID` and `Client Secret` immediately
   - The secret is shown only once!
   - Store temporarily in a secure location

### Step 2: Update Access Policy (Allow Both Tokens)

1. Go to: **Access** → **Applications** → `github-actions-internal`
2. Click **"Edit"** on the application
3. Navigate to the **Policies** tab
4. Edit policy `github-ci-service-auth`
5. Add an **Include** rule for the NEW token:
   - **Selector**: Service Token
   - **Value**: `github-actions-ci-v2`
6. **Keep the old token in the policy** (allows both to work during transition)
7. Click **"Save"**

### Step 3: Update GitHub Secrets

1. Navigate to: [GitHub Repository Secrets](https://github.com/jclee-homelab/proxmox/settings/secrets/actions)
2. Update `CF_ACCESS_CLIENT_ID`:
   - Click the secret → **"Update"**
   - Paste the new Client ID
3. Update `CF_ACCESS_CLIENT_SECRET`:
   - Click the secret → **"Update"**
   - Paste the new Client Secret

### Step 4: Verify New Token Works

1. Go to: [GitHub Actions](https://github.com/jclee-homelab/proxmox/actions)
2. Find workflow: **"Internal Service Access Test"**
3. Click **"Run workflow"** → **"Run workflow"**
4. Wait for completion (typically ~2 minutes)
5. Verify all service checks pass (green checkmarks)

### Step 5: Revoke Old Token

**Only after verifying the new token works:**

1. Go to: **Access** → **Service Auth** → **Service Tokens**
2. Find the old token (`github-actions-ci` or previous version)
3. Click **"Revoke"** → Confirm deletion
4. Go to: **Access** → **Applications** → `github-actions-internal`
5. Edit the policy to remove the old token from Include rules
6. Click **"Save"**

## Rollback Procedure

If the new token fails verification:

1. **Do NOT revoke the old token yet**
2. Revert GitHub secrets to old token values
3. Re-run the test workflow to confirm old token still works
4. Investigate the issue with the new token
5. If needed, delete the new token and start over

## Calendar Reminders

Set the following reminders:

| Reminder | When | Action |
|----------|------|--------|
| **Token Expiry Warning** | 30 days before expiry | Begin rotation procedure |
| **Token Expiry** | Expiry date | Token stops working if not rotated |

### Current Schedule

- **Rotation Reminder**: 2027-01-05
- **Token Expiry**: 2027-02-04

## Troubleshooting

### "403 Forbidden" After Rotation

1. Verify GitHub secrets were updated correctly
2. Check that the new token is in the Access policy Include rules
3. Ensure the token hasn't expired
4. Try manually testing with curl:

```bash
curl -s -w "%{http_code}" \
  -H "CF-Access-Client-Id: YOUR_CLIENT_ID" \
  -H "CF-Access-Client-Secret: YOUR_CLIENT_SECRET" \
  https://grafana.jclee.me/api/health
```

### Token Not Appearing in Policy Dropdown

1. Verify the token was created successfully
2. Check you're in the correct Cloudflare account
3. Refresh the page and try again

### Workflow Fails After Secret Update

1. GitHub caches secrets - wait 1-2 minutes
2. Try re-running the workflow
3. Check the workflow logs for specific error messages

## Security Notes

- **Never commit tokens to code** - use GitHub Secrets only
- **Never share tokens via Slack/email** - use secure transfer methods
- **Rotate immediately** if a token is compromised
- **Audit token usage** in Cloudflare Zero Trust → Logs → Access

## References

- [Cloudflare Service Tokens Documentation](https://developers.cloudflare.com/cloudflare-one/identity/service-tokens/)
- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Cloudflare Access Policies](https://developers.cloudflare.com/cloudflare-one/policies/access/)

---

*Last Updated: 2026-02-04*
*Next Rotation: 2027-01-05*
