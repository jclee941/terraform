# 101-runner: GitHub Actions Self-hosted Runner

LXC container (VMID 101) running multiple GitHub Actions self-hosted runner instances for shared CI/CD across all repositories.

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

## Multi-Instance Runner Model

Each repo gets `RUNNER_COUNT` (default: 2) independent runner instances:

| Component | Naming Convention |
|-----------|------------------|
| Runner name | `homelab-101-{N}` (e.g. `homelab-101-1`, `homelab-101-2`) |
| Directory | `/home/runner/runners/instance-{N}/{repo}/` |
| Systemd service | `github-runner-{N}-{repo}.service` |
| Labels | `self-hosted,linux,x64,homelab` |

With 2 instances and 7 repos, GitHub picks an idle instance automatically when a job starts.

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

# Install dependencies (run once)
go run /opt/runner/scripts/setup-runner.go

# Register all repos with 2 instances each (default)
GITHUB_TOKEN="ghp_xxx" GITHUB_USER="qws941" \
  go run /opt/runner/scripts/register-all-repos.go

# Register all repos with 3 instances each
RUNNER_COUNT=3 GITHUB_TOKEN="ghp_xxx" GITHUB_USER="qws941" \
  go run /opt/runner/scripts/register-all-repos.go
```

### 3. Using in Workflows

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
# List all running instances
systemctl list-units 'github-runner-*'

# Status of specific instance
systemctl status github-runner-1-terraform
journalctl -u github-runner-2-terraform -f

# Register a single repo (all instances)
GITHUB_TOKEN="ghp_xxx" GITHUB_USER="qws941" \
  go run /opt/runner/scripts/register-repo.go <repo-name>

# Register a single repo (specific instance only)
GITHUB_TOKEN="ghp_xxx" GITHUB_USER="qws941" \
  go run /opt/runner/scripts/register-repo.go <repo-name> 1

# Unregister all
GITHUB_TOKEN="ghp_xxx" GITHUB_USER="qws941" \
  go run /opt/runner/scripts/unregister-all.go
```

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │        LXC 101 (runner)                  │
                    │        192.168.50.101                    │
                    │                                          │
                    │  ┌──────────────────────────────────┐    │
                    │  │  instance-1/                      │    │
                    │  │    repo-A/ → github-runner-1-A    │    │
                    │  │    repo-B/ → github-runner-1-B    │    │
                    │  └──────────────────────────────────┘    │
                    │  ┌──────────────────────────────────┐    │
                    │  │  instance-2/                      │    │
                    │  │    repo-A/ → github-runner-2-A    │    │
                    │  │    repo-B/ → github-runner-2-B    │    │
                    │  └──────────────────────────────────┘    │
                    │                                          │
                    │  ┌──────────────────────────────────┐    │
                    │  │   Docker Engine                   │    │
                    │  │   (for container-based jobs)      │    │
                    │  └──────────────────────────────────┘    │
                    └──────────────┬──────────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────────┐
                    │      GitHub API                          │
                    │  ┌──────┐ ┌──────┐ ┌──────┐             │
                    │  │repo-A│ │repo-B│ │repo-N│ ...         │
                    │  └──────┘ └──────┘ └──────┘             │
                    └─────────────────────────────────────────┘
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GITHUB_TOKEN` | Yes | — | GitHub PAT with `repo` scope |
| `GITHUB_USER` | Yes | — | GitHub username (e.g. `qws941`) |
| `RUNNER_COUNT` | No | `2` | Number of runner instances per repo |
| `RUNNER_VERSION` | No | `2.322.0` | Runner binary version |
| `RUNNER_ARCH` | No | `linux-x64` | Runner architecture |
| `SKIP_DOCKER` | No | — | Set to `1` to skip Docker install |

## Security Notes

- **GITHUB_TOKEN**: Requires `repo` scope for registration. Store securely (1Password recommended).
- **Unprivileged LXC**: Nesting enabled for Docker-in-Docker. Only trusted code should run.
- **Network**: Internal 192.168.50.0/24 only. Outbound via gateway for GitHub API access.
