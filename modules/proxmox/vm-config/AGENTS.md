# AGENTS: modules/proxmox/vm-config - VM Config Deployment

## OVERVIEW

Renders VM cloud-init/systemd/write-file artifacts and optionally deploys them over SSH with post-deploy service health checks. Includes Filebeat setup provisioner for log collection.

## WHERE TO LOOK

| Task                       | File           | Notes                                                                              |
| -------------------------- | -------------- | ---------------------------------------------------------------------------------- |
| Cloud-init render path     | `main.tf`      | `cloud_init_configs` local + `local_file.cloud_init`.                              |
| Systemd/write-files deploy | `main.tf`      | `deploy_systemd_services`, `deploy_vm_write_files` resources.                      |
| Health checks              | `main.tf`      | `health_check_systemd` with journal fallback.                                      |
| Filebeat setup             | `main.tf`      | `setup_filebeat` provisioner — idempotent install via `scripts/setup-filebeat.sh`. |
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
