# 101-runner: GitHub Actions Self-hosted Runner

LXC container (VMID 101) running GitHub Actions self-hosted runner for shared CI/CD across all repositories.

## Specs

| Property | Value |
|----------|-------|
| VMID | 101 |
| IP | 192.168.50.101 |
| OS | Debian 12 |
| CPU | 2 cores |
| Memory | 2048 MB |
| Disk | 32 GB |
| Privileged | No (unprivileged, nesting enabled) |

## Quick Start

### 1. Provision LXC (Terraform)

```bash
cd terraform/
terraform plan -target='module.lxc["runner"]'
terraform apply -target='module.lxc["runner"]'
```

### 2. Setup Runner

SSH into the container and run the setup script:

```bash
# From PVE host
ssh root@192.168.50.100 'pct exec 101 -- bash'

# Inside container — single repo
GITHUB_TOKEN="ghp_xxx" GITHUB_USER="qws941" \
  bash /opt/runner/scripts/setup-runner.sh

# Inside container — ALL repos (creates runner per repo)
GITHUB_TOKEN="ghp_xxx" GITHUB_USER="qws941" \
  bash /opt/runner/scripts/register-all-repos.sh
```

### 3. Using in Workflows

Add `runs-on: self-hosted` to your GitHub Actions workflow:

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, x64, homelab]
    steps:
      - uses: actions/checkout@v4
      - run: echo "Running on homelab runner!"
```

## Runner Labels

| Label | Description |
|-------|-------------|
| `self-hosted` | Standard self-hosted tag |
| `linux` | OS type |
| `x64` | Architecture |
| `homelab` | Custom: identifies homelab runners |

## Management

```bash
# Single runner mode
systemctl status github-runner
journalctl -u github-runner -f

# Multi-repo mode
systemctl list-units 'github-runner-*'
systemctl status github-runner-<repo>
journalctl -u github-runner-<repo> -f

# Register additional repo
GITHUB_TOKEN="ghp_xxx" GITHUB_USER="qws941" \
  bash /opt/runner/scripts/register-repo.sh <repo-name>

# Unregister all
GITHUB_TOKEN="ghp_xxx" GITHUB_USER="qws941" \
  bash /opt/runner/scripts/unregister-all.sh
```

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │        LXC 101 (runner)              │
                    │        192.168.50.101                │
                    │                                      │
                    │  ┌─────────────────────────────────┐ │
                    │  │   GitHub Actions Runner          │ │
                    │  │   (systemd: github-runner-*)     │ │
                    │  └─────────┬───────────────────────┘ │
                    │            │                          │
                    │  ┌─────────▼───────────────────────┐ │
                    │  │   Docker Engine                  │ │
                    │  │   (for container-based jobs)     │ │
                    │  └─────────────────────────────────┘ │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │      GitHub API                      │
                    │  ┌──────┐ ┌──────┐ ┌──────┐         │
                    │  │repo-1│ │repo-2│ │repo-N│ ...     │
                    │  └──────┘ └──────┘ └──────┘         │
                    └─────────────────────────────────────┘
```

## Security Notes

- **GITHUB_TOKEN**: Requires `repo` scope for registration. Store securely (Vault recommended).
- **Privileged LXC**: Required for Docker-in-Docker. Only trusted code should run on this runner.
- **Network**: Internal 192.168.50.0/24 only. Outbound via gateway for GitHub API access.
