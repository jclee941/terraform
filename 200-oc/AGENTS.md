# AGENTS: 200-oc — OpenCode Dev Machine

> **Host**: VM 200 | **IP**: 192.168.50.200 | **Status**: template-only

**IP:** 192.168.50.200
**VMID:** 200
**Type:** VM (QEMU)
**Status:** Active

## OVERVIEW

OpenCode development VM. Provisioned via `100-pve/main.tf` as `jclee-dev`. Runs OpenCode agent runtime, SSH server, and development tooling. External SSH access via `ssh.jclee.me` (CF tunnel).

## STRUCTURE

```
200-oc/
├── AGENTS.md    # This file
└── README.md    # Service documentation
```

## WHERE TO LOOK

| Task             | Location                                           | Notes                          |
| ---------------- | -------------------------------------------------- | ------------------------------ |
| Host inventory   | `100-pve/envs/prod/hosts.tf` → `hosts.jclee-dev`   | ID 200, .200, ssh+rdp+opencode |
| VM definition    | `100-pve/main.tf` → `vm_definitions.jclee-dev`     | QEMU VM with cloud-init        |
| SSH tunnel       | `300-cloudflare/locals.tf` → `tcp_services.ssh`    | `ssh.jclee.me` → .200:22       |
| SSH tunnel (alt) | `300-cloudflare/locals.tf` → `tcp_services.oc-ssh` | `oc-ssh.jclee.me` → .200:22    |
| RDP tunnel       | `300-cloudflare/locals.tf` → `tcp_services.oc-rdp` | `oc-rdp.jclee.me` → .200:3389  |
| CF Access policy | `300-cloudflare/access.tf` → `tcp_services`        | 720h session, email auth       |
| Firewall rules   | `100-pve/firewall.tf`                              | VM-level security group        |

## CONVENTIONS

- VM provisioned by Terraform — do not mutate config via Proxmox UI.
- SSH and RDP access via Cloudflare tunnel only.
- IPs reference `var.jclee_dev_ip` in `300-cloudflare/` — do not hardcode.
- Host key is `jclee-dev` in hosts.tf (not `oc`).

## ANTI-PATTERNS

- Do not expose ports directly without CF tunnel + Access policy.
- Do not hardcode 192.168.50.200 in Cloudflare config — use `var.jclee_dev_ip`.
- Do not SSH into this VM for config mutation — use IaC.
