# AGENTS: 80-jclee — Personal Workstation

**VMID:** 80
**IP:** 192.168.50.80
**Status:** Active (CF tunnel: 80-jclee)
**Tunnel ID:** 8419f66e-255a-4535-88d3-515010c60ac8

## OVERVIEW

Personal workstation VM. Not provisioned by Terraform — inventory host only. RDP exposed externally via Cloudflare tunnel with Zero Trust email authentication (720h session).

## STRUCTURE

```
80-jclee/
├── AGENTS.md    # This file
├── BUILD.bazel  # Monorepo integration
├── OWNERS       # Access control
└── README.md    # Service documentation
```

## WHERE TO LOOK

| Task              | Location                                        | Notes                            |
| ----------------- | ----------------------------------------------- | -------------------------------- |
| RDP tunnel config | `300-cloudflare/locals.tf` → `tcp_services.rdp` | CF tunnel to .80:3389            |
| CF Access policy  | `300-cloudflare/access.tf` → `tcp_services`     | 720h session, email auth         |
| CF tunnel         | Cloudflare Dashboard                            | 80-jclee tunnel (not TF-managed) |

## CONVENTIONS

- This host is NOT Terraform-provisioned; changes are manual.
- RDP access is via Cloudflare tunnel only — do not expose port directly.
- The dedicated 80-jclee tunnel (8419f66e) is not managed by Terraform.

## ANTI-PATTERNS

- Do not expose RDP or SSH via public internet without CF tunnel + Access policy.
