# AGENTS: 101-runner

> **Host**: LXC 101 | **IP**: 192.168.50.101 | **Status**: template-only | **Updated**: 2026-04-08

## OVERVIEW

Dedicated GitHub Actions self-hosted runner infrastructure for the `qws941` user. Runs multiple runner instances per repository (default: 2) for parallel CI/CD execution. Each instance registers independently via per-repo tokens since `qws941` is a User account (not Organization). Provides direct access to homelab services (Proxmox, ELK) for integration testing and automated deployments. Includes Terraform and Bazel for infrastructure CI/CD.

**Resources (as of 2026-04-08):**
- Memory: **3072 MB (3 GB)** - increased from 768MB for Docker-in-Docker performance
- Swap: 1536 MB
- Cores: 2
- Disk: 32 GB
- NFS Cache: `/srv/gitlab-runner/cache` (Synology NAS via NFS v4.1)

## STRUCTURE

```
101-runner/
├── README.md                   # Hardware/Setup documentation
├── TEST_CHECKLIST.md          # Deployment verification checklist
├── config/
│   └── filebeat.yml           # Log forwarding to ELK (105)
├── templates/
│   └── filebeat.yml.tftpl     # Templated filebeat config
└── scripts/                   # Runner lifecycle management (Go)
    ├── setup-runner.go              # Dependency bootstrap, Docker, Terraform, Bazel
    ├── setup-gitlab-runner-with-cache.go  # Setup with NFS cache support
    ├── register-all-repos.go        # Multi-instance bulk registration
    ├── register-repo.go             # Single repo registration
    ├── unregister-all.go            # Safe cleanup with backward compat
    └── recover-runner.sh            # Recovery script for failed setups
```

## MULTI-INSTANCE MODEL

| Component | Convention |
|-----------|------------|
| Runner name | `homelab-101-{N}` |
| Directory | `/home/runner/runners/instance-{N}/{repo}/` |
| Systemd service | `github-runner-{N}-{repo}.service` |
| Instance count | `RUNNER_COUNT` env var (default: 2) |
| Labels | `self-hosted,linux,x64,homelab` |

## NFS CACHE ARCHITECTURE

```
Synology NAS (192.168.50.215)
  └── /volume1/gitlab-runner-cache (NFS Export)
       ↓ NFS v4.1
Proxmox Host (192.168.50.100)
  └── /mnt/gitlab-runner-cache (Host Mount)
       ↓ Bind Mount
LXC 101 (gitlab-runner)
  └── /srv/gitlab-runner/cache (Container Path)
       ↓ Volume Mount
GitLab Runner Docker executor jobs
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| **Add new repo** | `scripts/register-all-repos.go` | Auto-discovers all repos via API |
| **Add single repo** | `scripts/register-repo.go` | `go run scripts/register-repo.go <name> [instance]` |
| **Setup with cache** | `scripts/setup-gitlab-runner-with-cache.go` | Includes NFS cache configuration |
| **Troubleshoot logs**| `config/filebeat.yml` | Verified against Logstash:5044 |
| **Base dependencies**| `scripts/setup-runner.go` | Python, Docker, Terraform, Bazel |
| **Service Control** | `README.md` | `systemctl status github-runner-{N}-{repo}` |
| **Safe cleanup** | `scripts/unregister-all.go` | Token revocation + multi-instance + legacy cleanup |
| **Recovery** | `scripts/recover-runner.sh` | Restore failed runner setups |

## CONVENTIONS

- **Governance**: Managed by Terraform (`module.lxc["runner"]`). VMID 101 is fixed.
- **Isolation**: Each instance×repo gets a dedicated systemd service and working directory.
- **Labels**: Jobs MUST use `runs-on: [self-hosted, homelab]` to target this runner.
- **Networking**: Unprivileged LXC with `nesting=1` enabled for Docker-in-Docker support.
- **Naming**: Follows `{VMID}-{HOSTNAME}` (101-runner) for Proxmox and GitHub identifiers.
- **Script Safety**: Keep scripts repeatable and safe for reruns during recovery.
- **Scaling**: Increase `RUNNER_COUNT` to add more parallel capacity per repo.
- **Cache Usage**: Docker executor configured to use `/srv/gitlab-runner/cache` for build cache.

## ANTI-PATTERNS

- **NO manual config** inside LXC. Use scripts or Terraform remote-exec.
- **NO shared state** between repos. Each runner instance is independent.
- **NO plaintext tokens**. Use environment variables or 1Password integration.
- **NO direct SSH**. Use `ssh root@pve 'pct exec 101 -- bash'` from PVE host.
- **NO persistent storage** in work dirs. Cleaned by `unregister-all.go`.
- **NO remote registration**. Do not run registration scripts from non-runner hosts.

## COMMANDS

```bash
# Setup with NFS cache
go run scripts/setup-gitlab-runner-with-cache.go

# Register all repos (default 2 instances)
GITHUB_TOKEN="ghp_xxx" GITHUB_USER="qws941" \
  go run scripts/register-all-repos.go

# Check runner status
systemctl status github-runner-1-terraform
journalctl -u github-runner-2-terraform -f

# Verify NFS cache mount
pct exec 101 -- df -h /srv/gitlab-runner/cache
pct exec 101 -- ls -la /srv/gitlab-runner/cache
```

## NOTES

- Memory increased to 3GB (2026-04-08) for improved Docker-in-Docker performance.
- NFS cache reduces build times by persisting Docker layers across jobs.
- Registry routing available at `registry.jclee.me` for private Docker registry.
- Filebeat logs forwarded to ELK (Logstash on 192.168.50.105:5044).
