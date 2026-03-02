# AGENTS: modules/proxmox/lxc-config - LXC Config Deployment

## OVERVIEW
Renders container service/config artifacts and optionally deploys them over SSH with post-deploy health checks. Includes Filebeat setup provisioner for log collection.

## STRUCTURE
```text
lxc-config/
├── main.tf
├── variables.tf
├── outputs.tf
└── AGENTS.md
```

## INTERFACE
| Kind | Name | Type | Required | Description |
|------|------|------|----------|-------------|
| variable | `lxc_containers` | `map(object)` | No | Container config map (services, files, compose, deploy flags). |
| variable | `deploy_lxc_configs` | `bool` | No | Enables SSH deploy provisioners for rendered artifacts. |
| variable | `enable_health_checks` | `bool` | No | Enables post-deploy `systemctl is-active` checks. |
| variable | `ssh_private_key` | `string` | No | SSH key content for remote `file`/`remote-exec` provisioners. |
| variable | `ssh_user` | `string` | No | SSH user for target LXCs (default `root`). |
| variable | `mcp_host` | `string` | Yes | MCPHub host IP passed into templates/services. |
| output | `lxc_configs` | - | - | Per-container rendered path and service/config summary. |
| output | `service_count` | - | - | Total managed systemd service count. |

## CONSUMERS
- Called by `100-pve/lxc_configs.tf` via `module.lxc_config`.

## WHERE TO LOOK
| Task                      | File           | Notes                                                                                |
| ------------------------- | -------------- | ------------------------------------------------------------------------------------ |
| Service/config flattening | `main.tf`      | `systemd_services`, `config_files`, `docker_composes` locals.                        |
| Generated local artifacts | `main.tf`      | `local_file` and `local_sensitive_file` under `configs/lxc-*`.                       |
| Remote deploy + checks    | `main.tf`      | `null_resource` file/exec provisioners and health check logic.                       |
| Filebeat setup            | `main.tf`      | `setup_filebeat` provisioner — idempotent install via `scripts/install-filebeat.sh`. |
| Input schema              | `variables.tf` | `lxc_containers` map shape and deploy toggles.                                       |

## CONVENTIONS
- Keep template rendering deterministic before remote deploy phase.
- Keep deploy toggles (`deploy_lxc_configs`, health checks) explicit per environment.
- Keep SSH operations idempotent through content hashes in `triggers`.
- Filebeat provisioner runs `install-filebeat.sh` with container-specific Logstash endpoint config.

## ANTI-PATTERNS

- Do not manually edit generated `configs/lxc-*` artifacts and expect persistence.
- Do not remove health-check guards when enabling automatic deploy.
- Do not embed secrets in template files tracked by git.
- Do not skip Filebeat setup for new containers — all LXCs must report logs.
