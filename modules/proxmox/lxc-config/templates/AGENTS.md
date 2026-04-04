# AGENTS: modules/proxmox/lxc-config/templates — LXC Config Templates

## OVERVIEW
Terraform templates for LXC container configuration deployment. Used by `lxc-config` module.

## STRUCTURE
```
templates/
└── *.tftpl                # Configuration file templates
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Service configs | `*.tftpl` | Template files for services |
| Filebeat config | `filebeat.yml.tftpl` | Log shipping to ELK |

## CONVENTIONS
- Use `templatefile()` for rendering
- Pass `hosts` map for IP references
- Render to `/opt/{service}/`

## ANTI-PATTERNS
- NEVER hardcode service IPs
- NEVER commit secrets in templates
