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
├── 200-oc/                    # OpenCode dev machine (VM)
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

| Task                          | Location                                                                      | Notes                                                                                 |
| ----------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Core infra orchestration      | `100-pve/main.tf`                                                             | Hub workspace (958 lines). Pulls hosts inventory, firewall rules, and renders configs.                 |
| Host inventory SoT            | `100-pve/envs/prod/hosts.tf`                                                  | Single source for internal host IP/port metadata.                                     |
| Generated config rules        | `100-pve/configs/AGENTS.md`                                                   | Rendered outputs are generated-only; no manual edits.                                 |
| Proxmox module behavior       | `modules/proxmox/`                                                            | LXC, VM, lxc-config, vm-config, config-renderer.                                      |
| Proxmox LXC module internals  | `modules/proxmox/lxc/AGENTS.md`                                               | Container lifecycle, validation, and provider constraints.                            |
| Proxmox VM module internals   | `modules/proxmox/vm/AGENTS.md`                                                | VM clone/cloud-init boundaries and validation rules.                                  |
| Proxmox config rendering hub  | `modules/proxmox/config-renderer/AGENTS.md`                                   | Generated config pipeline contract and output rules.                                  |
| Proxmox deploy modules        | `modules/proxmox/lxc-config/AGENTS.md`, `modules/proxmox/vm-config/AGENTS.md` | SSH deploy orchestration, health checks, filebeat setup, and generated artifacts.     |
| Shared modules                | `modules/shared/`                                                             | Cross-stack reusable modules (`onepassword-secrets`).                                 |
| Shared 1Password details      | `modules/shared/onepassword-secrets/AGENTS.md`                                | Item schema, output contract, and test-safe lookup pattern.                           |
| CI topology (overview)        | `.github/AGENTS.md`                                                           | Runner, risk tiers, reusable workflow usage, issue/PR templates.                      |
| CI workflow details           | `.github/workflows/AGENTS.md`                                                 | Pairing rules, `_terraform-*` templates, drift matrix.                                |
| CI custom actions             | `.github/actions/AGENTS.md`                                                   | Composite action contracts (`terraform-setup`, `notify-failure`).                     |
| Workstation PC                | `80-jclee/AGENTS.md`                                                          | Windows workstation (physical PC); RDP + SSH via CF tunnel.                           |
| OpenCode dev VM             | `200-oc/AGENTS.md`                                                            | VM 200 at .200; SSH via `ssh.jclee.me`, RDP via `oc-rdp.jclee.me`.                    |
| Self-hosted runner            | `101-runner/AGENTS.md`                                                        | GitHub Actions runner on LXC 101; multi-repo registration.                            |
| Reverse proxy                 | `102-traefik/AGENTS.md`                                                       | Traefik ingress, TLS, MCP resilient middleware.                                       |
| DNS resolver                  | `103-coredns/AGENTS.md`                                                       | Split DNS on LXC 103; Corefile + Docker Compose + filebeat.                           |
| Observability stack           | `104-grafana/AGENTS.md`                                                       | Prometheus + Grafana (16 dashboards) + TF-managed alerts.                             |
| Dashboard catalog             | `104-grafana/dashboards/AGENTS.md`                                            | Dashboard JSON SSoT, UID/title discipline, and panel edit rules.                      |
| Logging stack                 | `105-elk/AGENTS.md`                                                           | ES 8.17.0 + Logstash + Kibana; 3-tier ILM, filebeat autodiscovery, logstash-exporter, Logpush HTTP ingest. |
| Error tracking                | `106-glitchtip/AGENTS.md`                                                     | GlitchTip (Sentry alternative) on LXC 106.                                            |
| Supabase service              | `107-supabase/AGENTS.md`                                                      | Self-hosted Supabase (PostgreSQL, Auth, Realtime).                                    |
| Archon AI                     | `108-archon/AGENTS.md`                                                        | AI knowledge management + MCP server on LXC 108.                                      |
| MCPHub gateway                | `112-mcphub/AGENTS.md`                                                        | Unified MCP gateway; `mcp_servers.json` SSoT.                                         |
| MCP catalog validation        | `112-mcphub/validate_mcps.py`                                                 | Validates schema, port uniqueness, secret-pattern leaks.                              |
| Synology NAS                  | `215-synology/AGENTS.md`                                                      | Physical NAS inventory host (not TF-provisioned).                                     |
| YouTube VM                    | `220-youtube/AGENTS.md`                                                       | YouTube media server with WARP.                                                       |
| Cloudflare infra              | `300-cloudflare/AGENTS.md`                                                    | External infra + Worker + Zero Trust Access + Logpush + tunnels.                      |
| Worker-specific rules         | `300-cloudflare/workers/synology-proxy/AGENTS.md`                             | Route/auth/cache implementation constraints.                                          |
| Cloudflare automation scripts | `300-cloudflare/scripts/AGENTS.md`                                            | Secret collection/sync/audit/deploy script governance.                                |
| GitHub org management         | `301-github/AGENTS.md`                                                        | 14 repos, rulesets, webhooks, environments.                                           |
| SafetyWallet service          | `310-safetywallet/AGENTS.md`                                                  | External SafetyWallet service; CF tunnel.                                             |
| Slack workspace management    | `320-slack/AGENTS.md`                                                         | Channel lifecycle, usergroups via `pablovarela/slack` provider.                       |
| Test harness overview         | `tests/AGENTS.md`                                                             | Native `terraform test` conventions and layout.                                       |
| Proxmox tests                 | `tests/modules/proxmox/AGENTS.md`                                             | Mock provider patterns, fixture discipline.                                           |
| Shared module tests           | `tests/modules/shared/AGENTS.md`                                              | onepassword module test and mock rules.                                               |
| Integration tests             | `tests/integration/AGENTS.md`                                                 | Config pipeline end-to-end test strategy.                                             |
| Workspace tests               | `tests/workspaces/AGENTS.md`                                                  | Workspace variable-validation test strategy.                                          |
| Operational docs              | `docs/AGENTS.md`                                                              | Runbooks, ADRs, token rotation, architecture docs.                                    |
| Runbook execution guides      | `docs/runbooks/AGENTS.md`                                                     | Incident and operations procedures; command-first and rollback-ready.                 |
| Utility scripts               | `scripts/AGENTS.md`                                                           | Production verification, PR automation, drift check, filebeat setup.                  |
| n8n workflow JSONs            | `scripts/n8n-workflows/AGENTS.md`                                             | Exported automation SSoT; runtime workflows must mirror committed JSON.               |
| Filebeat deployment           | `scripts/setup-filebeat.sh`                                                   | Idempotent filebeat install across LXC/VM hosts.                                      |
| GitHub issue/PR templates     | `.github/ISSUE_TEMPLATE/`, `.github/pull_request_template.md`                 | Bug, feature, service request templates + PR template.                                |
| Architecture decisions        | `docs/adr/`                                                                   | Architecture Decision Records.                                                        |

## CONVENTIONS

- Build governance: every source directory keeps `BUILD.bazel` + `OWNERS`.
- Layout: flat `{NNN}-{svc}/` directories; `modules/{provider}/` + `modules/shared/`.
- Numbering: `1-255` internal (`192.168.50.{NNN}`), `300+` external providers.
- Paths: use relative module sources (`../modules/{provider}/{module}`), no absolute/local-only shortcuts.
- SSoT: `hosts.tf` for host inventory; `112-mcphub/mcp_servers.json` for MCP server catalog.
- Generated pipeline: templates and inventories feed `module.config_renderer` to produce `100-pve/configs/...`.
- CI model: 3 core workflows + 2 reusable `_terraform-*` workflows + service plan/apply pairs + automation workflows.
- Secrets: inject via env/GitHub secrets/1Password service account or 1Password Connect Server; keep placeholders in tracked config. Provider workspaces use `modules/shared/onepassword-secrets` for structured secret lookup. Connect Server on LXC 112 port 8090 provides rate-limit-free alternative to service account token.
- Log collection: Filebeat agents deployed to all LXC/VM hosts via `setup_filebeat` provisioner in lxc-config/vm-config modules. Cloudflare Worker traces ingested via Logpush → Logstash HTTP input.

## ANTI-PATTERNS (THIS PROJECT)

- NEVER hand-edit Terraform-rendered outputs under `100-pve/configs/` or service `tf-configs/` directories.
- NEVER hardcode IPs in workspace logic; route through `module.hosts` inventory.
- NEVER perform manual Terraform state edits outside Terraform CLI workflows.
- NEVER commit `.env`, `.tfvars`, API keys, or runtime secret dumps. Only `105-elk/terraform/terraform.tfstate` is tracked in git (force-added); all other workspace state files are gitignored.
- NEVER use `as any`, `@ts-ignore`, `@ts-expect-error`, or empty catch blocks.
- NEVER SSH directly into Terraform-managed LXCs for config mutation; use IaC or `pct exec` for diagnostics only.

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
- Infra scopes: `100-pve/AGENTS.md`, `100-pve/envs/prod/AGENTS.md`, `100-pve/configs/AGENTS.md`
- CI scopes: `.github/AGENTS.md`, `.github/workflows/AGENTS.md`, `.github/actions/AGENTS.md`
- Module scopes: `modules/AGENTS.md`, `modules/proxmox/AGENTS.md`, `modules/proxmox/lxc/AGENTS.md`, `modules/proxmox/vm/AGENTS.md`, `modules/proxmox/lxc-config/AGENTS.md`, `modules/proxmox/vm-config/AGENTS.md`, `modules/proxmox/config-renderer/AGENTS.md`, `modules/shared/AGENTS.md`, `modules/shared/onepassword-secrets/AGENTS.md`
- Test scopes: `tests/AGENTS.md`, `tests/modules/proxmox/AGENTS.md`, `tests/modules/shared/AGENTS.md`, `tests/integration/AGENTS.md`, `tests/workspaces/AGENTS.md`
- Service scopes: `101-runner/AGENTS.md`, `102-traefik/AGENTS.md`, `103-coredns/AGENTS.md`, `104-grafana/AGENTS.md`, `105-elk/AGENTS.md`, `106-glitchtip/AGENTS.md`, `107-supabase/AGENTS.md`, `108-archon/AGENTS.md`, `112-mcphub/AGENTS.md`
- Dashboard scope: `104-grafana/dashboards/AGENTS.md`
- Dev/workstation scopes: `80-jclee/AGENTS.md`, `200-oc/AGENTS.md`, `215-synology/AGENTS.md`, `220-youtube/AGENTS.md`
- External scopes: `300-cloudflare/AGENTS.md`, `300-cloudflare/scripts/AGENTS.md`, `300-cloudflare/workers/AGENTS.md`, `300-cloudflare/workers/synology-proxy/AGENTS.md`, `301-github/AGENTS.md`, `310-safetywallet/AGENTS.md`, `320-slack/AGENTS.md`
- Operational scopes: `docs/AGENTS.md`, `docs/runbooks/AGENTS.md`, `scripts/AGENTS.md`, `scripts/n8n-workflows/AGENTS.md`

## NOTES

- Risk-tier merge policy: critical and medium paths require manual merge; low-risk paths can auto-merge.
- Self-hosted runner (101) is required for Terraform workflows with homelab network dependencies.
- n8n webhook workflows must be published via UI after import.
- Only `105-elk/terraform/terraform.tfstate` is tracked in git; all other workspaces use local backend with gitignored state. CI apply workflows on the self-hosted runner manage state locally.
- State locking: all workspaces use `backend "local" {}` with no remote locking. Concurrent apply is prevented by GHA `concurrency` groups (`cancel-in-progress: false`) and disabled local `make apply`.
- 100-pve workflows (`terraform-plan.yml`, `terraform-apply.yml`) are intentionally standalone (not using `_terraform-*` reusable templates) due to Proxmox-specific secrets, resource import scripts, and plan-file-based apply flow.
- Drift detection runs on push to master AND on a weekday schedule (Mon-Fri 00:00 UTC / 09:00 KST).
- Filebeat Docker autodiscovery is enabled on all LXC hosts; new Docker services are auto-indexed.
- Cloudflare Logpush sends Worker trace events to Logstash HTTP input (port 8080) via CF tunnel + M2M service token.
- SSH/RDP access to homelab hosts tunneled through Cloudflare Zero Trust (720h session, email auth).
- CoreDNS (LXC 103) is default DNS for all LXC/VM hosts (`192.168.50.103`); wildcard `*.jclee.me` → Traefik, `*.homelab.local` → per-host A records, external → 1.1.1.1/8.8.8.8.
- Traefik (LXC 102) uses Cloudflare DNS-01 certificate resolver (`cf`) for TLS; runs as systemd service, not Docker.
- 1Password Connect Server (`connect-api` + `connect-sync`) on LXC 112 port 8090 provides rate-limit-free vault access for Terraform workspaces.
- MCPHub runs 9/10 MCP servers (archon blocked — requires OpenAI API key); catalog validated by `112-mcphub/validate_mcps.py`.

## Review guidelines

These rules apply to all PR reviews (human and automated, including ChatGPT Codex).

### Security

- No hardcoded secrets, passwords, API keys, or tokens in `.tf` files.
- Secrets must come from 1Password via `module.onepassword_secrets`.
- No `*.tfvars` or `.env` files committed.
- Provider auth via environment variables or 1Password, never inline.

### Terraform best practices

- `terraform fmt` compliance (canonical HCL formatting).
- `terraform validate` must pass.
- Provider versions pinned in `versions.tf`.
- Module sources use relative paths (`../modules/...`), not absolute.
- Variables should have `description` and `type` constraints.
- Use `validation` blocks for variable input checking.
- Wrap 1Password lookups with `try(..., "")` for test compatibility.

### Naming and structure

- New directories must have `BUILD.bazel` and `OWNERS` files.
- Resource naming: `snake_case` for Terraform, `kebab-case` for container hostnames.
- Output key names in `onepassword-secrets` must remain stable (breaking change if renamed).
- IP addresses only in `hosts.tf`, never hardcoded in workspace logic.

### Generated files — do NOT review

- Files under `100-pve/configs/` are auto-generated by Terraform.
- Files under `**/tf-configs/` are auto-generated.
- Files under `modules/proxmox/*/configs/` are auto-generated.
- Do not suggest changes to these files.

### Risk tiers

Changes to these paths require extra scrutiny:

- **Critical**: `100-pve/`, `modules/`, `300-cloudflare/`, `301-github/`, `102-traefik/`
- **Medium**: `105-elk/`, `107-supabase/`, `108-archon/`, `112-mcphub/`
- **Low**: all other service directories

### Common anti-patterns to flag

- `as any`, `@ts-ignore`, `@ts-expect-error` in TypeScript files.
- Empty `catch` blocks.
- `terraform.tfstate` or state files in commits.
- Manual edits to generated config directories.
- SSH into Terraform-managed LXCs for config changes (use IaC).
- Hardcoded IPs instead of referencing `module.hosts`.
- Missing `BUILD.bazel` / `OWNERS` in new directories.
