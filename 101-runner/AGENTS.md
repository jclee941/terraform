# AGENTS: 101-runner

> **Host**: LXC 101 | **IP**: 192.168.50.101 | **Status**: template-only

**Updated:** 2026-03-04
**Target:** LXC 101 (Debian 12)
**IP:** 192.168.50.101

## OVERVIEW
Dedicated GitHub Actions self-hosted runner infrastructure for the `qws941-lab` organization. Runs multiple org-level runner instances (default: 2) for parallel CI/CD execution. Each instance registers once at the org level and automatically serves all repositories. Provides direct access to homelab services (Proxmox, ELK) for integration testing and automated deployments. Includes Terraform and Bazel for infrastructure CI/CD.

## STRUCTURE
```
101-runner/
├── BUILD.bazel          # Monorepo integration (all_configs)
├── OWNERS               # Access control (Infrastructure)
├── README.md            # Hardware/Setup documentation
├── config/
│   └── filebeat.yml     # Log forwarding to ELK (105)
├── templates/
│   └── filebeat.yml.tftpl  # Templated filebeat config
└── scripts/             # Runner lifecycle management
    ├── setup-runner.sh       # Dependency bootstrap, Docker, Terraform, Bazel
    ├── register-runners.sh   # Org-level multi-instance registration
    └── unregister-all.sh     # Safe cleanup with backward compat
    ```

## MULTI-INSTANCE MODEL

| Component | Convention |
|-----------|-----------|
| Runner name | `homelab-101-{N}` |
| Directory | `/home/runner/runners/instance-{N}/` |
| Systemd service | `github-runner-{N}.service` |
| Instance count | `RUNNER_COUNT` env var (default: 2) |
| Labels | `self-hosted,linux,x64,homelab` |
| Scope | Organization-level (serves all repos) |

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| **Register runners** | `scripts/register-runners.sh` | Org-level registration, `RUNNER_COUNT` instances |
| **Troubleshoot logs**| `config/filebeat.yml` | Verified against Logstash:5044 |
| **Base dependencies**| `scripts/setup-runner.sh` | Python, Docker, Terraform, Bazel |
| **Service Control** | `README.md` | `systemctl status github-runner-{N}` |
| **Safe cleanup** | `scripts/unregister-all.sh` | Token revocation + multi-instance + legacy cleanup |

## CONVENTIONS
- **Governance**: Managed by Terraform (`module.lxc["runner"]`). VMID 101 is fixed.
- **Org-level**: Runners register at org level via `register-runners.sh`. No per-repo tokens.
- **Labels**: Jobs MUST use `runs-on: [self-hosted, homelab]` to target this runner.
- **Networking**: Unprivileged LXC with `nesting=1` enabled for Docker-in-Docker support.
- **Naming**: Follows `{VMID}-{HOSTNAME}` (101-runner) for Proxmox and GitHub identifiers.
- **Script Safety**: Keep scripts repeatable and safe for reruns during recovery.
- **Scaling**: Increase `RUNNER_COUNT` to add more parallel capacity.
- **Token Scope**: `GITHUB_TOKEN` requires `admin:org` scope (not just `repo`).

## ANTI-PATTERNS
- **NO manual config** inside LXC. Use scripts or Terraform remote-exec.
- **NO per-repo registration**. Use org-level registration only.
- **NO plaintext tokens**. Use environment variables or 1Password integration.
- **NO direct SSH**. Use `ssh root@pve 'pct exec 101 -- bash'` from PVE host.
- **NO persistent storage** in work dirs. Cleaned by `unregister-all.sh`.
- **NO remote registration**. Do not run registration scripts from non-runner hosts.
