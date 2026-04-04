# AGENTS: 112-mcphub/templates — MCPHub Service Templates

## OVERVIEW
Terraform templates for MCPHub VM (112) deployment.

## STRUCTURE
```
templates/
├── cloud-init.yml.tftpl   # Cloud-init for VM provisioning
└── docker-compose.yml.tftpl  # MCPHub stack
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| VM provisioning | `cloud-init.yml.tftpl` | User data for cloud-init |
| Service stack | `docker-compose.yml.tftpl` | MCPHub + dependencies |

## CONVENTIONS
- Cloud-init installs Docker, pulls configs
- Compose mounts config from host
- Uses VM module from `modules/proxmox/vm`

## ANTI-PATTERNS
- NEVER commit cloud-init passwords
- NEVER use default SSH keys
