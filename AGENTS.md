# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-25 14:15:00 Asia/Seoul
**Commit:** ce04972
**Branch:** master
**Style:** Google3 Monorepo (Bazel)

## OVERVIEW

Terraform monorepo for homelab and external infrastructure providers. Primary orchestration is `100-pve/main.tf`; adjacent service directories hold provider-specific workspaces, templates, and operational assets.

## READ ORDER

1. Read this file for global conventions.
2. Read the nearest scoped `AGENTS.md` in the directory you modify.
3. If multiple scopes apply, prefer the deepest scope.

## STRUCTURE

```text
terraform/
├── 80-jclee/                   # Windows workstation PC (RDP + SSH via CF tunnel)
├── 100-pve/                    # Primary infra orchestrator + config rendering
├── 101-runner/                 # Self-hosted GitHub Actions runner (LXC)
├── 102-traefik/                # Reverse proxy templates + reserved TF workspace
├── 103-coredns/                # Split DNS resolver (LXC)
├── 104-grafana/                # Observability stack + grafana provider workspace
├── 105-elk/                    # ELK stack + elasticstack provider workspace
├── 106-glitchtip/              # Error tracking service
├── 107-supabase/               # Supabase service
├── 108-archon/                 # Archon service + reserved provider workspace
├── 112-mcphub/                 # MCPHub service + MCP catalog/templates
├── 200-oc/                     # OpenCode dev machine (VM)
├── 215-synology/               # Physical NAS inventory + syslog config
├── 220-youtube/                # YouTube media server VM
├── 300-cloudflare/             # External Cloudflare infra + Worker
├── 301-github/                 # External GitHub org/repo management
├── 310-safetywallet/           # SafetyWallet external service (CF tunnel)
├── 320-slack/                  # Slack workspace management (channels, usergroups)
├── modules/
│   ├── proxmox/                # lxc, vm, config rendering modules
│   └── shared/                 # cross-stack reusable modules
├── tests/                      # terraform test suites (module, integration, workspace)
├── docs/                       # runbooks, ADRs, architecture docs
├── .github/workflows/          # 35 workflows (core, reusable, service, automation)
└── scripts/                    # operational automation scripts
```

## WHERE TO LOOK

| Task                     | Location                         | Notes                                                         |
| ------------------------ | -------------------------------- | ------------------------------------------------------------- |
| Core infra orchestration | `100-pve/main.tf`                | Hub workspace (958 lines). Hosts, firewall, config rendering. |
| Host inventory SoT       | `100-pve/envs/prod/hosts.tf`     | Single source for internal host IP/port metadata.             |
| Proxmox modules          | `modules/proxmox/AGENTS.md`      | LXC, VM, lxc-config, vm-config, config-renderer.              |
| Shared modules           | `modules/shared/AGENTS.md`       | Cross-stack reusable modules (`onepassword-secrets`).         |
| CI/CD pipeline           | `.github/AGENTS.md`              | 35 workflows, risk tiers, reusable templates.                 |
| MCP catalog              | `112-mcphub/mcp_servers.json`    | SSoT for MCP server catalog; validated by `validate_mcps.py`. |
| External infra           | `300-cloudflare/`, `301-github/` | Cloudflare + GitHub org management.                           |
| Test harness             | `tests/AGENTS.md`                | Native `terraform test` conventions and layout.               |
| Operational docs         | `docs/AGENTS.md`                 | Runbooks, ADRs, architecture docs.                            |
| Utility scripts          | `scripts/AGENTS.md`              | Production verification, PR automation, filebeat setup.       |

## CONVENTIONS

- Build governance: every source directory keeps `BUILD.bazel` + `OWNERS`.
- Layout: flat `{NNN}-{svc}/` directories; `modules/{provider}/` + `modules/shared/`.
- Numbering: `1-255` internal (`192.168.50.{NNN}`), `300+` external providers.
- Paths: use relative module sources (`../modules/{provider}/{module}`).
- SSoT: `hosts.tf` for host inventory; `112-mcphub/mcp_servers.json` for MCP catalog.
- Generated pipeline: templates → `module.config_renderer` → `100-pve/configs/`.
- CI: 3 core + 2 reusable `_terraform-*` + service plan/apply pairs + automation workflows.
- Secrets: 1Password via `modules/shared/onepassword-secrets`. Connect Server on LXC 112:8090.
- Logs: Filebeat on all LXC/VM hosts → Logstash 105. CF Logpush → Logstash HTTP input.
- Naming: `snake_case` for Terraform resources, `kebab-case` for container hostnames.
- Provider versions pinned in `versions.tf`. Variables need `description` + `type` + `validation`.
- Wrap 1Password lookups with `try(..., "")` for test compatibility.

## ANTI-PATTERNS

- NEVER hand-edit rendered outputs under `100-pve/configs/` or `**/tf-configs/`.
- NEVER hardcode IPs; route through `module.hosts` inventory.
- NEVER perform manual Terraform state edits outside CLI workflows.
- NEVER commit `.env`, `.tfvars`, API keys, or state files. Exception: `105-elk/terraform/terraform.tfstate`.
- NEVER SSH into TF-managed LXCs for config mutation; use IaC or `pct exec` diagnostics only.
- NEVER use `as any`, `@ts-ignore`, `@ts-expect-error`, or empty catch blocks.

## COMMANDS

```bash
make plan SVC=pve                                # plan only (apply via CI)
make plan SVC=cloudflare
make plan SVC=slack
python3 112-mcphub/validate_mcps.py
make test
make test-unit
make test-integration
bazel build //... && bazel test //...
```

## AGENTS HIERARCHY

- Root: `AGENTS.md`
- Infra: `100-pve/`, `100-pve/envs/prod/`, `100-pve/configs/`
- CI: `.github/`, `.github/workflows/`, `.github/actions/`
- Modules: `modules/`, `modules/proxmox/` (lxc, vm, lxc-config, vm-config, config-renderer), `modules/shared/` (onepassword-secrets)
- Tests: `tests/`, `tests/modules/proxmox/`, `tests/modules/shared/`, `tests/integration/`, `tests/workspaces/`
- Services: 101-runner, 102-traefik, 103-coredns, 104-grafana (+dashboards), 105-elk, 106-glitchtip, 107-supabase, 108-archon, 112-mcphub
- Hosts: 80-jclee, 200-oc, 215-synology, 220-youtube
- External: 300-cloudflare (+scripts, workers/synology-proxy), 301-github, 310-safetywallet, 320-slack
- Ops: docs (+runbooks), scripts (+n8n-workflows)

## NOTES

- State: local backend, no remote locking. Concurrency via GHA `concurrency` groups (`cancel-in-progress: false`).
- Runner: LXC 101 required for TF workflows with homelab network dependencies.
- 100-pve workflows are standalone (not reusable templates) due to Proxmox-specific secrets and plan-file flow.
- Drift detection: push to master + weekday schedule (Mon-Fri 00:00 UTC / 09:00 KST).
- DNS: CoreDNS (103) default; `*.jclee.me` → Traefik, `*.homelab.local` → per-host A records, external → 1.1.1.1/8.8.8.8.
- TLS: Traefik (102) uses CF DNS-01 resolver; runs as systemd service, not Docker.
- Access: SSH/RDP via CF Zero Trust tunnels (720h session, email auth).
- 1Password Connect Server on LXC 112:8090 provides rate-limit-free vault access.

## Review guidelines

- No hardcoded secrets in `.tf`; secrets via `module.onepassword_secrets`.
- `terraform fmt` + `terraform validate` must pass. `BUILD.bazel` + `OWNERS` in new dirs.
- Generated files (`configs/`, `tf-configs/`, `modules/proxmox/*/configs/`) — do NOT review.
- Risk tiers: **Critical** (100-pve, modules, 300-cloudflare, 301-github, 102-traefik), **Medium** (105-elk, 107-supabase, 108-archon, 112-mcphub), **Low** (all others, auto-merge eligible).
- Flag: hardcoded IPs, missing `BUILD.bazel`/`OWNERS`, state files in commits, manual config edits.
