# AGENTS: modules/proxmox/vm-config/templates — VM Config Templates

## OVERVIEW
Terraform templates for VM (QEMU) configuration. Used by `vm-config` module.

## STRUCTURE
```
templates/
├── cloud-init.yml.tftpl   # Cloud-init user data
└── *.tftpl                # Service-specific templates
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Cloud-init | `cloud-init.yml.tftpl` | VM provisioning data |
| Docker Compose | `docker-compose.yml.tftpl` | Container orchestration |

## CONVENTIONS
- Cloud-init uses NoCloud datasource
- Write files to `/var/lib/cloud/...`
- Run commands on first boot

## ANTI-PATTERNS
- NEVER commit SSH private keys
- NEVER use weak default passwords
- NEVER skip cloud-init package updates
