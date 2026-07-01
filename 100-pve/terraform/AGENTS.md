# AGENTS: 100-pve/terraform — Core Infrastructure Definitions

## OVERVIEW
Terraform configuration workspace containing the complete infrastructure-as-code definitions for the homelab. Orchestrates four LXC containers and three VMs via modular composition.

## STRUCTURE
```
terraform/
├── main.tf              # Provider setup, remote state refs, module calls
├── locals.tf            # VM definitions, container sizing, host mappings
├── vm_configs.tf        # VM-specific config deployment modules
├── lxc_configs.tf       # LXC-specific config deployment modules
├── secrets.tf           # 1Password secrets integration
├── firewall.tf          # Proxmox firewall rules
├── checks.tf            # TF 1.5+ validation checks
├── outputs.tf           # Workspace outputs
├── variables.tf         # Input variables
├── versions.tf          # Provider constraints
└── configs/             # Rendered config outputs (auto-generated)
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Container provisioning | `main.tf` → `module.lxc` | Calls `../../modules/proxmox/lxc` for `local.containers`. |
| VM provisioning | `main.tf` → `module.vm` | Calls `../../modules/proxmox/vm` for `local.vm_definitions`. |
| Host inventory | `locals.tf` → `module.hosts` | Imports from `../envs/prod/hosts.tf` |
| Memory sizing | `locals.tf` → `container_sizing` | Active LXC sizing map. |
| Filebeat setup | `lxc_configs.tf`, `vm_configs.tf` | `setup_filebeat` provisioner blocks |
| Config rendering | `secrets.tf` → `module.config_renderer` | Template → file conversion |

## CONVENTIONS
- Use `module.hosts.hosts[name].ip` for all IP references
- Container sizing defined in `locals.tf` `container_sizing` map
- Use relative paths from this nested root: `../../modules/...`, `../../{NNN}-{svc}/templates/`
- All guests get Filebeat via `setup_filebeat` provisioner

## ANTI-PATTERNS
- NEVER hand-edit files in `configs/` — regenerate via Terraform workflows
- NEVER hardcode IPs in `.tf` files — use `module.hosts`
- NEVER use `count` or `for_each` for heterogeneous resources

## COMMANDS
```bash
terraform init              # Initialize providers
terraform plan              # Preview changes
terraform validate          # Syntax validation
terraform fmt -recursive    # Format all files
# apply via CI/CD only; local make apply is disabled
```

## NOTES

- Memory budget: GitHub Actions Runner (LXC 101) is 3072MB / 1536MB swap.
- VM memory is defined in `local.vm_definitions`; do not duplicate budget totals here.
- NFS cache mount configured for LXC 101 at `/srv/runner/cache`.
