# 200-oc — OpenCode Dev Machine (VM)

| ----------------- | ----------------------- |
| Host ID | 200 |
| IP | 192.168.50.200 |
| Roles | development, workstation|
| Ports | SSH (22), RDP (3389), OpenCode (8090) |
| Provisioned by TF | Yes (100-pve) |

## Overview

OpenCode development VM on Proxmox. Terraform-provisioned via `100-pve/main.tf` as `jclee-dev`. Hosts OpenCode agent runtime and development tooling.

## External Access

- **SSH**: `ssh.jclee.me` — CF tunnel → .200:22 (Zero Trust email auth, 720h session)
- **SSH (alt)**: `oc-ssh.jclee.me` — CF tunnel → .200:22
- **RDP**: `oc-rdp.jclee.me` — CF tunnel → .200:3389

## Integration

- Host inventory: `100-pve/envs/prod/hosts.tf` → `hosts.jclee-dev`
- VM definition: `100-pve/main.tf` → `vm_definitions`
- CF SSH: `300-cloudflare/locals.tf` → `tcp_services.ssh`
- CF SSH (alt): `300-cloudflare/locals.tf` → `tcp_services.oc-ssh`
- CF RDP: `300-cloudflare/locals.tf` → `tcp_services.oc-rdp`
- CF access: `300-cloudflare/access.tf` → `tcp_services`
- Firewall: `100-pve/firewall.tf` → VM-level security group
