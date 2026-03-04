# 101-runner: GitHub Actions Self-hosted Runner

LXC container (VMID 101) running multiple GitHub Actions self-hosted runner instances registered at the **organization level** (`qws941-lab`). A single registration serves all repos in the org automatically.

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

## Org-Level Runner Model

Runners register once at the organization level and automatically serve **all repositories** in `qws941-lab`. No per-repo registration needed.

| Component | Naming Convention |
|-----------|------------------|
| Runner name | `homelab-101-{N}` (e.g. `homelab-101-1`, `homelab-101-2`) |
| Directory | `/home/runner/runners/instance-{N}/` |
| Systemd service | `github-runner-{N}.service` |
| Labels | `self-hosted,linux,x64,homelab` |
| Instance count | `RUNNER_COUNT` env var (default: 2) |

With 2 instances, GitHub picks an idle runner automatically when any repo triggers a job.

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
bash /opt/runner/scripts/setup-runner.sh

# Register org-level runners (2 instances by default)
GITHUB_TOKEN="ghp_xxx" \
  bash /opt/runner/scripts/register-runners.sh

# Register with 3 instances
RUNNER_COUNT=3 GITHUB_TOKEN="ghp_xxx" \
  bash /opt/runner/scripts/register-runners.sh
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
systemctl status github-runner-1
journalctl -u github-runner-2 -f

# Unregister all instances
GITHUB_TOKEN="ghp_xxx" \
  bash /opt/runner/scripts/unregister-all.sh
```

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │        LXC 101 (runner)                  │
                    │        192.168.50.101                    │
                    │                                          │
                    │  ┌──────────────────────────────────┐    │
                    │  │  instance-1/                      │    │
                    │  │    → github-runner-1.service       │    │
                    │  │    → homelab-101-1                 │    │
                    │  └──────────────────────────────────┘    │
                    │  ┌──────────────────────────────────┐    │
                    │  │  instance-2/                      │    │
                    │  │    → github-runner-2.service       │    │
                    │  │    → homelab-101-2                 │    │
                    │  └──────────────────────────────────┘    │
                    │                                          │
                    │  ┌──────────────────────────────────┐    │
                    │  │   Docker Engine                   │    │
                    │  │   (for container-based jobs)      │    │
                    │  └──────────────────────────────────┘    │
                    └──────────────┬──────────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────────┐
                    │   GitHub (qws941-lab org)                 │
                    │  ┌──────────────────────────────────┐    │
                    │  │  Org-level runner pool             │    │
                    │  │  Serves ALL repos automatically    │    │
                    │  └──────────────────────────────────┘    │
                    └─────────────────────────────────────────┘
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GITHUB_TOKEN` | Yes | — | GitHub PAT with `admin:org` scope |
| `GITHUB_ORG` | No | `qws941-lab` | GitHub organization name |
| `RUNNER_COUNT` | No | `2` | Number of runner instances |
| `RUNNER_VERSION` | No | `2.322.0` | Runner binary version |
| `RUNNER_ARCH` | No | `linux-x64` | Runner architecture |
| `SKIP_DOCKER` | No | — | Set to `1` to skip Docker install |

## Security Notes

- **GITHUB_TOKEN**: Requires `admin:org` scope for org-level runner registration. Store securely (1Password recommended).
- **Unprivileged LXC**: Nesting enabled for Docker-in-Docker. Only trusted code should run.
- **Network**: Internal 192.168.50.0/24 only. Outbound via gateway for GitHub API access.
