# AGENTS: 101-runner

> **Host**: LXC 101 | **IP**: 192.168.50.101 | **Status**: template-only

## OVERVIEW
GitHub Actions self-hosted runner assets for the `qws941` user. Terraform owns the LXC lifecycle from `100-pve/terraform`; this directory owns runner bootstrap, registration scripts, and Filebeat source config.

## STRUCTURE
```
101-runner/
├── README.md              # Hardware/setup notes
├── config/
│   └── filebeat.yml       # Static reference Filebeat config
├── templates/
│   └── filebeat.yml.tftpl # Rendered Filebeat template
└── scripts/               # Runner lifecycle tools (Go + wrappers)
```

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Add all repos | `scripts/register-all-repos.go` | API discovery, default 2 runner instances per repo. |
| Add one repo | `scripts/register-repo.go` | `go run scripts/register-repo.go <repo> [instance]`. |
| Bootstrap host | `scripts/setup-runner.go` | Installs Docker, Terraform, Bazel, and runner deps. |
| Safe cleanup | `scripts/unregister-all.go` | Token revocation plus legacy service cleanup. |
| Log shipping | `templates/filebeat.yml.tftpl` | Rendered by `100-pve/terraform` into the LXC. |
| Runtime notes | `README.md` | Systemd service and NFS cache operations. |

## RUNNER MODEL
| Component | Convention |
|-----------|------------|
| Runner name | `homelab-101-{N}` |
| Work dir | `/home/runner/runners/instance-{N}/{repo}/` |
| Systemd unit | `github-runner-{N}-{repo}.service` |
| Instance count | `RUNNER_COUNT` env var, default `2` |
| Labels | `self-hosted,linux,x64,homelab` |

## CONVENTIONS
- VMID 101 is fixed and managed by `module.lxc["runner"]`.
- Jobs target this host with `runs-on: [self-hosted, homelab]`.
- NFS cache path is `/srv/runner/cache`, mounted from Synology via the PVE host.
- Each instance and repository has isolated service state and working directories.
- Keep scripts repeatable; registration and cleanup are normal recovery operations.

## ANTI-PATTERNS
- Do not manually mutate persistent config inside the LXC; use Terraform or scripts.
- Do not share runner work directories across repos or instances.
- Do not commit registration tokens or place them in templates.
- Do not run registration scripts from arbitrary remote hosts.
- Do not store durable build artifacts in runner work directories.

## COMMANDS
```bash
go run scripts/setup-runner.go
GITHUB_TOKEN="$GITHUB_TOKEN" GITHUB_USER="qws941" go run scripts/register-all-repos.go
systemctl status github-runner-1-terraform
journalctl -u github-runner-2-terraform -f
pct exec 101 -- df -h /srv/runner/cache
```

## NOTES
- Resource sizing lives in `100-pve/terraform/locals.tf`, not here.
- Filebeat forwards runner logs to Logstash on host 105.
- Registry routing is available at `registry.jclee.me` for private images.
