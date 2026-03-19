# AGENTS: modules/proxmox/vm-config - VM Config Deployment

## OVERVIEW
Renders VM cloud-init/systemd/write-file artifacts and optionally deploys them over SSH with post-deploy service health checks. Includes Filebeat setup provisioner for log collection.

## STRUCTURE
```text
vm-config/
├── main.tf
├── variables.tf
├── outputs.tf
└── AGENTS.md
```

## INTERFACE
| Kind | Name | Type | Required | Description |
|------|------|------|----------|-------------|
| variable | `vms` | `map(object)` | No | VM config map (cloud-init, services, write_files, deploy flags). |
| variable | `deploy_vm_configs` | `bool` | No | Enables SSH deployment of rendered VM artifacts. |
| variable | `enable_health_checks` | `bool` | No | Enables service activity checks after deploy. |
| variable | `health_check_delay` | `number` | No | Delay before health probes to allow startup. |
| variable | `ssh_user` | `string` | No | SSH user for VM remote provisioners. |
| variable | `ssh_private_key` | `string` | No | SSH private key content for deployment resources. |
| output | `vm_configs` | - | - | Per-VM rendered config and systemd artifact paths. |
| output | `cloud_init_paths` | - | - | Map of VM name to generated cloud-init file path. |

## CONSUMERS
- Called by `100-pve/vm_configs.tf` via `module.vm_config`.

## WHERE TO LOOK
| Task                       | File           | Notes                                                                              |
| -------------------------- | -------------- | ---------------------------------------------------------------------------------- |
| Cloud-init render path     | `main.tf`      | `cloud_init_configs` local + `local_file.cloud_init`.                              |
| Systemd/write-files deploy | `main.tf`      | `deploy_systemd_services`, `deploy_vm_write_files` resources.                      |
| Health checks              | `main.tf`      | `health_check_systemd` with journal fallback.                                      |
| Filebeat setup             | `main.tf`      | `install_filebeat` provisioner — idempotent install via `scripts/install-filebeat.sh`. |
| VM input schema            | `variables.tf` | `vms` map, deploy toggles, SSH options.                                            |

## CONVENTIONS
- Keep generated files under `configs/vm-*` deterministic and reproducible.
- Keep SSH identity explicit via `ssh_user` + private key path.
- Keep `triggers` hash-based for predictable re-runs.
- Filebeat provisioner runs setup script with VM-specific Logstash endpoint config.

## ANTI-PATTERNS

- Do not hand-edit generated VM config artifacts.
- Do not skip ownership/permission setup for deployed write-files.
- Do not disable service health checks in production paths without explicit incident reason.
- Do not skip Filebeat setup for new VMs — all VMs must report logs.
