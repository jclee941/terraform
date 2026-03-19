# AGENTS: 80-jclee — Personal Workstation
**IP:** 192.168.50.80
**Status:** Active (CF tunnel: 80-jclee)
**Tunnel ID:** 8419f66e-255a-4535-88d3-515010c60ac8
## OVERVIEW

Personal workstation (physical PC). Not provisioned by Terraform — inventory host only. RDP and SSH exposed externally via Cloudflare tunnel with Zero Trust email authentication (720h session).

## STRUCTURE

```
80-jclee/
├── AGENTS.md    # This file
└── README.md    # Service documentation
```

## WHERE TO LOOK
| Task              | Location                                        | Notes                            |
| ----------------- | ---------------------------------------------------- | -------------------------------------- |
| Host inventory    | `100-pve/envs/prod/hosts.tf` → `hosts.jclee`         | ID 80, .80, ssh+rdp ports              |
| RDP tunnel config | `300-cloudflare/locals.tf` → `tcp_services.rdp`      | CF tunnel to .80:3389 (via variable)   |
| SSH tunnel config | `300-cloudflare/locals.tf` → `tcp_services.jclee-ssh` | CF tunnel to .80:22 (via variable)     |
| CF Access policy  | `300-cloudflare/access.tf` → `tcp_services`          | 720h session, email auth               |
| CF tunnel         | `300-cloudflare/tunnel.tf` → `jclee`                 | TF-managed tunnel resource             |
| External RDP      | `rdp.jclee.me`                                       | CF tunnel → .80:3389                   |
| External SSH      | `jclee-ssh.jclee.me`                                 | CF tunnel → .80:22                    |


## CONVENTIONS
- This host is NOT Terraform-provisioned; changes are manual.
- RDP and SSH access is via Cloudflare tunnel only — do not expose ports directly.
- The `80-jclee` tunnel is Terraform-managed (`300-cloudflare/tunnel.tf`).
- IPs reference `var.jclee_ip` in `300-cloudflare/` — do not hardcode.

## ANTI-PATTERNS
- Do not expose RDP or SSH via public internet without CF tunnel + Access policy.
- Do not hardcode 192.168.50.80 in Cloudflare config — use `var.jclee_ip`.
