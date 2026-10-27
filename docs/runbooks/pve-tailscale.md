# PVE Host Tailscale Subnet Router

## Scope

- In scope: Tailscale on the PVE bare-metal host `pve3` (192.168.50.100) acting as a subnet router for `192.168.50.0/24` and an exit node: install, login, route and exit node approval, verification, rollback.
- Out of scope: public HTTP routes (Cloudflare Tunnel, `300-cloudflare/`), Tailscale on guests or the Synology NAS, tailnet ACL policy.

## Inputs and Constraints

- The PVE host is **not** Terraform-provisioned (same as `pve-filebeat-deployment.md`), so this runbook is the source of truth for the host-level install.
- Placement (decided 2026-10-14): PVE host instead of the NAS or a dedicated LXC.
  - The host root is on the HDD (`pve` VG), outside the `ssd-nvme` thin pool that hit 100% on 2026-09-20, so the access path survives guest storage incidents.
  - The host has kernel TUN (`/dev/net/tun`). The Synology DSM 7 package runs in userspace networking mode: no `--accept-routes`, no Tailscale SSH, and reported stalls ([tailscale/tailscale#21747](https://github.com/tailscale/tailscale/issues/21747)).
  - A dedicated LXC would sit on the overcommitted `ssd-nvme` thin pool.
- Cloudflare Tunnel stays the public entry point (ADR-003). Tailscale carries private admin traffic (PVE UI `:8006`, SSH, SMB, RDP) and, for clients that select `pve3` as exit node, their internet traffic.
- `--accept-dns=false` keeps the hypervisor's static `/etc/resolv.conf`. IPv4 and IPv6 forwarding are both enabled: Tailscale raises an `IP forwarding is disabled` health warning once the exit node advertises `::/0`. The home network has no IPv6 upstream (netcheck `IPv6: no`), so exit traffic is IPv4-only in practice, and `vmbr0` already had per-interface IPv6 forwarding on, so its router-advertisement handling did not change.
- The PVE firewall is disabled (`100-pve/terraform/firewall.tf`). If it is re-enabled, allow the tailnet range `100.64.0.0/10` to the host's `8006` and `22`.
- Login is interactive. No auth key exists in the 1Password `homelab` vault; if one is introduced, store it there, never in the repo.

## Prerequisites

1. Root SSH to the PVE host (`ssh pve`).
2. A Tailscale account with admin console access (created on first login).

## Steps

### 1. Add the Tailscale apt repository

Refresh only this repository so the PVE and Debian sources are not touched.

```bash
ssh pve 'curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg &&
  curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list &&
  apt-get update -o Dir::Etc::sourcelist=sources.list.d/tailscale.list -o Dir::Etc::sourceparts=- -o APT::Get::List-Cleanup=0'
```

**Expected**: `pkgs.tailscale.com/stable/debian trixie/main` package lists fetched.

### 2. Install Tailscale

```bash
ssh pve 'apt-get install -s tailscale | grep -E "^(Inst|Remv)"'
ssh pve 'DEBIAN_FRONTEND=noninteractive apt-get install -y tailscale'
ssh pve 'systemctl is-enabled tailscaled; systemctl is-active tailscaled; tailscale version | head -1'
```

**Expected**: the simulation lists only `tailscale` and `tailscale-archive-keyring` with no `Remv` lines; then `enabled`, `active`, and the version (1.104.1 at install time).

### 3. Enable IPv4 forwarding persistently

```bash
ssh pve "printf '%s\n' '# Tailscale subnet router for 192.168.50.0/24 (docs/runbooks/pve-tailscale.md)' 'net.ipv4.ip_forward = 1' 'net.ipv6.conf.all.forwarding = 1' > /etc/sysctl.d/99-tailscale.conf && sysctl -p /etc/sysctl.d/99-tailscale.conf"
ssh pve 'systemd-analyze cat-config sysctl.d | grep -nE "^# /|forward"'
```

**Expected**: `net.ipv4.ip_forward = 1` and `net.ipv6.conf.all.forwarding = 1`, and the only forwarding lines follow the `# /etc/sysctl.d/99-tailscale.conf` header.

### 4. Bring Tailscale up and log in

```bash
ssh pve 'tailscale up --advertise-routes=192.168.50.0/24 --accept-dns=false'
```

Open the printed `https://login.tailscale.com/a/...` URL and log in; the command prints `Success.` and exits.
One warning is expected: `UDP GRO forwarding is suboptimally configured on vmbr0` (optional tuning, see Notes).

### 5. Approve the route and disable key expiry

In the admin console (https://console.tailscale.com/admin/machines), open the `...` menu of `pve3`:

1. **Edit route settings** → check `192.168.50.0/24` → **Save**.
2. **Disable key expiry** (otherwise the node must log in again when its key expires, 180 days by default).

### 6. Advertise the exit node

```bash
ssh pve 'tailscale set --advertise-exit-node'
ssh pve 'tailscale debug prefs' | python3 -c 'import json,sys; print(json.load(sys.stdin)["AdvertiseRoutes"])'
```

**Expected**: `['192.168.50.0/24', '0.0.0.0/0', '::/0']`; `tailscale set` keeps the other flags from step 4.

Then approve it in the admin console: `pve3` `...` menu → **Edit route settings** → check **Use as exit node** → **Save**.

If `tailscale status` still shows `IP forwarding is disabled` after step 3, re-run `ssh pve 'tailscale set --advertise-exit-node'`; the health check is re-evaluated on that prefs update.

### 7. Verify

```bash
ssh pve 'tailscale status --json' | python3 -c 'import json,sys; j=json.load(sys.stdin); s=j["Self"]; print(j["BackendState"], s["TailscaleIPs"], s.get("PrimaryRoutes"), "0.0.0.0/0" in s["AllowedIPs"], s.get("KeyExpiry"))'
ssh pve 'tailscale debug prefs' | python3 -c 'import json,sys; p=json.load(sys.stdin); print(p["AdvertiseRoutes"], p["CorpDNS"])'
ssh pve 'tailscale netcheck 2>/dev/null | grep -E "UDP|IPv4|PortMapping"'
ssh pve 'tailscale status | grep -A3 "Health check" || echo "no health warnings"'
```

**Expected**:

- `Running ['100.x.y.z', 'fd7a:...'] ['192.168.50.0/24'] True None` (route approved, exit node approved, key expiry disabled).
- `['192.168.50.0/24', '0.0.0.0/0', '::/0'] False` (route and exit node advertised, Tailscale DNS not accepted).
- `UDP: true`, a public IPv4 address, and a port mapping method (direct connections possible).
- `no health warnings`.
- From a tailnet client off the LAN (for example a phone on LTE), `https://192.168.50.100:8006` opens the PVE UI.
- With `pve3` selected as exit node on that client, a what-is-my-IP site shows the home public IP.

## Rollback

```bash
# Stop offering the exit node only (keeps the subnet route)
ssh pve 'tailscale set --advertise-exit-node=false'

# Disconnect and stop advertising, keep the package
ssh pve 'tailscale down'

# Full removal
ssh pve 'tailscale logout; apt-get purge -y tailscale tailscale-archive-keyring; rm -f /etc/apt/sources.list.d/tailscale.list /usr/share/keyrings/tailscale-archive-keyring.gpg'
ssh pve 'rm -f /etc/sysctl.d/99-tailscale.conf && sysctl -w net.ipv4.ip_forward=0 net.ipv6.conf.all.forwarding=0'
```

Then remove `pve3` from the admin console machine list.

## Notes

- Updates arrive with the regular `apt-get upgrade` on the host; the Tailscale repository is a normal apt source.
- Optional throughput tuning suggested by `tailscale up` (not applied, and not persistent across reboots): `ethtool -K vmbr0 rx-udp-gro-forwarding on rx-gro-list off` (https://tailscale.com/s/ethtool-config-udp-gro).
- Clients: install Tailscale on the phone or laptop and log in with the same account. Linux clients need `tailscale up --accept-routes` to use the subnet route; other platforms accept it by default.
- Exit node use: pick `pve3` under **Exit node** in the client app and turn on **Allow local network access** to keep reaching the client's own LAN. Throughput is bounded by the home uplink, and a relayed (DERP) path is slower than a direct one; `tailscale ping <client-ip>` on pve3 shows which path is in use.
- If a client's local network is also `192.168.50.0/24` (the ASUS router default), the subnet route collides with that LAN; reach the host by its Tailscale IP (`ssh pve 'tailscale ip -4'`) instead.

## Completion Record

- Host: `pve3` (`192.168.50.100`)
- Tailscale version at install: `1.104.1`
- Installed and logged in (`BackendState: Running`): `yes` (2026-10-14)
- Route `192.168.50.0/24` approved (`PrimaryRoutes`): `yes` (2026-10-14)
- Key expiry disabled: `no` as of 2026-10-14 (key expires 2027-04-12)
- Exit node approved (`0.0.0.0/0` in `AllowedIPs`): `yes` (2026-10-14; IPv6 forwarding enabled to clear the health warning)
- Off-LAN client test (PVE UI over Tailscale): `pending` (phone joined the tailnet on 2026-10-14; browser test not done yet)
- Verified by: `<name>`
- Date: `2026-10-14`
