# AGENTS: modules/proxmox/lxc-config - LXC Config Deployment

## OVERVIEW
Renders container service/config artifacts and optionally deploys them over SSH with post-deploy health checks.

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Service/config flattening | `main.tf` | `systemd_services`, `config_files`, `docker_composes` locals. |
| Generated local artifacts | `main.tf` | `local_file` and `local_sensitive_file` under `configs/lxc-*`. |
| Remote deploy + checks | `main.tf` | `null_resource` file/exec provisioners and health check logic. |
| Input schema | `variables.tf` | `lxc_containers` map shape and deploy toggles. |

## CONVENTIONS
- Keep template rendering deterministic before remote deploy phase.
- Keep deploy toggles (`deploy_lxc_configs`, health checks) explicit per environment.
- Keep SSH operations idempotent through content hashes in `triggers`.

## ANTI-PATTERNS
- Do not manually edit generated `configs/lxc-*` artifacts and expect persistence.
- Do not remove health-check guards when enabling automatic deploy.
- Do not embed secrets in template files tracked by git.
