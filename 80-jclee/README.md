# 80-jclee — Personal Workstation

| Property          | Value                |
| ----------------- | -------------------- |
| VMID              | 80                   |
| IP                | 192.168.50.80        |
| Roles             | workstation          |
| Ports             | RDP (3389)           |
| CF Tunnel         | 80-jclee (8419f66e)  |
| Provisioned by TF | No                   |

## Overview

Personal workstation VM in the homelab. Not managed by Terraform — this directory serves as inventory documentation only.

## External Access

- **RDP**: Tunneled via Cloudflare (`rdp.jclee.me`) with Zero Trust email auth (720h session)

## Integration

- CF tunnel: `300-cloudflare/locals.tf` → `tcp_services.rdp`
- CF access: `300-cloudflare/access.tf` → `tcp_services`
