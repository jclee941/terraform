# 80-jclee — Personal Workstation (Physical PC)
| ----------------- | -------------------- |
| Host ID           | 80                   |
| IP                | 192.168.50.80        |
| Roles             | workstation          |
| Ports             | RDP (3389), SSH (22) |
| CF Tunnel         | 80-jclee (8419f66e)  |
| Provisioned by TF | No                   |
## Overview

Personal workstation (physical PC) in the homelab. Not managed by Terraform — this directory serves as inventory documentation only.

## External Access
- **RDP**: Tunneled via Cloudflare (`rdp.jclee.me`) with Zero Trust email auth (720h session)
- **SSH**: Tunneled via Cloudflare (`jclee-ssh.jclee.me`) with Zero Trust email auth (720h session)

## Integration

- Host inventory: `100-pve/envs/prod/hosts.tf` → `hosts.jclee`
- CF tunnel: `300-cloudflare/tunnel.tf` → `cloudflare_zero_trust_tunnel_cloudflared.jclee`
- CF RDP: `300-cloudflare/locals.tf` → `tcp_services.rdp`
- CF SSH: `300-cloudflare/locals.tf` → `tcp_services.jclee-ssh`
- CF access: `300-cloudflare/access.tf` → `tcp_services`
- PVE firewall: Not TF-managed (host ID 80 < provider minimum 100)
