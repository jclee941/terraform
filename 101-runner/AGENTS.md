# AGENTS: 101-runner

> **Host**: LXC 101 | **IP**: 192.168.50.101 | **Status**: template-only

**Updated:** 2026-03-04
**Target:** LXC 101 (Debian 12)
**IP:** 192.168.50.101

## OVERVIEW
Dedicated GitHub Actions self-hosted runner infrastructure for the `qws941` user. Runs multiple runner instances per repository (default: 2) for parallel CI/CD execution. Each instance registers independently via per-repo tokens since `qws941` is a User account (not Organization). Provides direct access to homelab services (Proxmox, ELK) for integration testing and automated deployments. Includes Terraform and Bazel for infrastructure CI/CD.

## STRUCTURE
```
101-runner/
├── README.md            # Hardware/Setup documentation
├── config/
│   └── filebeat.yml     # Log forwarding to ELK (105)
├── templates/
│   └── filebeat.yml.tftpl  # Templated filebeat config
└── scripts/             # Runner lifecycle management (Go)
    ├── setup-runner.go       # Dependency bootstrap, Docker, Terraform, Bazel
    ├── register-all-repos.go # Multi-instance bulk registration (N instances × M repos)
    ├── register-repo.go      # Single repo registration (all or specific instance)
    └── unregister-all.go     # Safe cleanup with backward compat
```

## MULTI-INSTANCE MODEL

| Component | Convention |
|-----------|-----------|
| Runner name | `homelab-101-{N}` |
| Directory | `/home/runner/runners/instance-{N}/{repo}/` |
| Systemd service | `github-runner-{N}-{repo}.service` |
| Instance count | `RUNNER_COUNT` env var (default: 2) |
| Labels | `self-hosted,linux,x64,homelab` |

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| **Add new repo** | `scripts/register-all-repos.go` | Auto-discovers all repos via API |
| **Add single repo** | `scripts/register-repo.go` | `go run scripts/register-repo.go <name> [instance]` |
| **Troubleshoot logs**| `config/filebeat.yml` | Verified against Logstash:5044 |
| **Base dependencies**| `scripts/setup-runner.go` | Python, Docker, Terraform, Bazel |
| **Service Control** | `README.md` | `systemctl status github-runner-{N}-{repo}` |
| **Safe cleanup** | `scripts/unregister-all.go` | Token revocation + multi-instance + legacy cleanup |

## CONVENTIONS
- **Governance**: Managed by Terraform (`module.lxc["runner"]`). VMID 101 is fixed.
- **Isolation**: Each instance×repo gets a dedicated systemd service and working directory.
- **Labels**: Jobs MUST use `runs-on: [self-hosted, homelab]` to target this runner.
- **Networking**: Unprivileged LXC with `nesting=1` enabled for Docker-in-Docker support.
- **Naming**: Follows `{VMID}-{HOSTNAME}` (101-runner) for Proxmox and GitHub identifiers.
- **Script Safety**: Keep scripts repeatable and safe for reruns during recovery.
- **Scaling**: Increase `RUNNER_COUNT` to add more parallel capacity per repo.

## ANTI-PATTERNS
- **NO manual config** inside LXC. Use scripts or Terraform remote-exec.
- **NO shared state** between repos. Each runner instance is independent.
- **NO plaintext tokens**. Use environment variables or 1Password integration.
- **NO direct SSH**. Use `ssh root@pve 'pct exec 101 -- bash'` from PVE host.
- **NO persistent storage** in work dirs. Cleaned by `unregister-all.go`.
- **NO remote registration**. Do not run registration scripts from non-runner hosts.
