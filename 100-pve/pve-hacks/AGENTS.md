# AGENTS: 100-pve/pve-hacks — Proxmox VE Manual Workarounds

## OVERVIEW
Scripts and documentation for manual Proxmox VE interventions. Use sparingly — prefer Terraform.

## STRUCTURE
```
pve-hacks/
└── *.sh / *.md            # One-off scripts and docs
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Emergency fixes | `*.sh` | When Terraform can't help |
| Recovery docs | `*.md` | Disaster recovery procedures |

## CONVENTIONS
- Document WHY the hack was needed
- Reference GitHub issue or ADR
- Prefer Go scripts per monorepo policy

## ANTI-PATTERNS
- NEVER use hacks as permanent solutions
- NEVER skip documenting the workaround
- NEVER apply without peer review
