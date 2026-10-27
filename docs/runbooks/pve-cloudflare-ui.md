# PVE Web UI via Cloudflare Tunnel (proxmox.jclee.me)

## Scope

- In scope: exposing the Proxmox VE web UI of `pve3` (192.168.50.100:8006) at
  `https://proxmox.jclee.me` through the existing `jclee-dev` Cloudflare Tunnel
  connector: ingress rule, DNS record, verification, rollback.
- Out of scope: Tailscale admin access (`pve-tailscale.md`), Terraform-managed
  Cloudflare resources (`300-cloudflare/`), the PVE host install itself.

## Inputs and Constraints

- The `jclee-dev` tunnel (`446cc972-9f62-4807-928e-d6423a87769f`) is
  **remotely-managed** (dashboard/API config, `config_src: cloudflare`). Its
  `cloudflared` connector is a native systemd service on the jclee-dev VM
  (`/etc/cloudflared/config.yml` is a stale local copy and is ignored while the
  remote config is in effect). The same tunnel also serves `ssh`, `vscode`,
  `vnc`, and `sns` on `jclee.me`.
- This route is **not** Terraform-managed. `300-cloudflare/terraform` declares a
  separate, unrelated tunnel topology; editing the live `jclee-dev` tunnel is an
  operational action owned by this runbook, matching how `ssh`/`vnc`/`sns` are
  managed today.
- Origin is HTTPS with the PVE self-signed certificate, so the ingress rule sets
  `originRequest.noTLSVerify = true`. The proxied Cloudflare record provides the
  public TLS; WebSockets (noVNC/xterm.js console) work because the zone has
  WebSockets enabled.
- The PVE UI has no Cloudflare Access policy in front of it: authentication is
  Proxmox's own login (PVE realm / API token). Add a Zero Trust Access
  application if browser SSO is required.
- Credentials (Cloudflare API, PVE API token) live in the 1Password `homelab`
  vault, never in this file or the repo.

## Prerequisites

1. Cloudflare API credentials for the `jclee.me` zone/account (1Password
   `homelab/cloudflare`). Tunnel-config writes require the Global API Key +
   email; a scoped token returns 403 on `cfd_tunnel` configuration.
2. The account ID, zone ID, and tunnel ID above.
3. `curl` and `dig`.

## Steps

### 1. Back up the current tunnel configuration

```bash
ACCOUNT=<cloudflare_account_id>; TUNNEL=446cc972-9f62-4807-928e-d6423a87769f
curl -s -H "X-Auth-Email: $CF_EMAIL" -H "X-Auth-Key: $CF_API_KEY" \
  "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT/cfd_tunnel/$TUNNEL/configurations" \
  | tee ~/.cloudflared/remote-config.bak-proxmox-$(date +%Y%m%dT%H%M).json | jq '.result.version'
```

**Expected**: the current config version prints (e.g. `35`) and the backup file
is written.

### 2. Add the proxmox ingress rule

Insert, immediately before the final `http_status:404` catch-all, keeping every
existing rule and `warp-routing` intact:

```json
{ "hostname": "proxmox.jclee.me",
  "service": "https://192.168.50.100:8006",
  "originRequest": { "noTLSVerify": true } }
```

PUT the full edited config back to the same `/configurations` endpoint. The
version increments and the connector logs `Updated to new configuration` within
seconds (`journalctl -u cloudflared -f` on jclee-dev).

### 3. Create the DNS record

```bash
ZONE=<cloudflare_zone_id>
curl -s -X POST -H "X-Auth-Email: $CF_EMAIL" -H "X-Auth-Key: $CF_API_KEY" \
  "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
  -d '{"type":"CNAME","name":"proxmox","content":"'"$TUNNEL"'.cfargotunnel.com","proxied":true,"ttl":1,"comment":"Proxmox VE UI (pve3) via jclee-dev tunnel"}'
```

**Expected**: `success: true`; a proxied CNAME to `<tunnel>.cfargotunnel.com`.

## Verification

```bash
# UI reachable (200 + PVE title)
curl -sS -i https://proxmox.jclee.me/ | grep -E 'HTTP/|Proxmox Virtual Environment'
# PVE API answers through the tunnel (token from 1Password homelab/proxmox)
curl -s -H "Authorization: PVEAPIToken=$PVE_TOKEN" \
  https://proxmox.jclee.me/api2/json/version
# Unauthenticated write is rejected by pveproxy (401), not by Cloudflare (403)
curl -s -o /dev/null -w '%{http_code}\n' -X PUT \
  https://proxmox.jclee.me/api2/json/nodes/pve3/config
```

**Expected**: `HTTP/2 200` with `pve3 - Proxmox Virtual Environment` in the body;
`/api2/json/version` returns JSON (`"version":"9.1.x"`); the unauthenticated PUT
returns `401`. In a browser, `https://proxmox.jclee.me` renders the
`Proxmox VE Login` window.

## Rollback

```bash
# Restore the saved tunnel config (PUT the backup's .result.config back), then:
curl -s -X DELETE -H "X-Auth-Email: $CF_EMAIL" -H "X-Auth-Key: $CF_API_KEY" \
  "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records/<proxmox_record_id>"
```

Deleting the ingress rule and the DNS record returns the tunnel to its previous
state; the connector reloads automatically. Removing only the DNS record makes
the hostname unresolvable while leaving the ingress rule dormant.
