# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-20 21:30:00 Asia/Seoul
**Commit:** 667ce19
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
├── 100-pve/                    # Primary infra orchestrator + config rendering
├── 101-runner/                 # Self-hosted GitHub Actions runner (LXC)
├── 102-traefik/                # Reverse proxy templates + reserved TF workspace
├── 104-grafana/                # Observability stack + grafana provider workspace
├── 105-elk/                    # ELK stack + elasticstack provider workspace
├── 106-glitchtip/              # Error tracking service
├── 107-supabase/               # Supabase service
├── 108-archon/                 # Archon service + reserved provider workspace
├── 112-mcphub/                 # MCPHub service + MCP catalog/templates
├── 200-oc/                     # Dev VM + OpenCode config generation pipeline
├── 215-synology/               # Physical NAS inventory
├── 220-staging/                # Staging VM
├── 300-cloudflare/             # External Cloudflare infra + Worker
├── 301-github/                 # External GitHub org/repo management
├── modules/
│   ├── proxmox/                # lxc, vm, config rendering modules
│   └── shared/                 # cross-stack reusable modules
├── tests/                      # terraform test suites (module, integration, workspace)
├── .github/workflows/          # 28 workflows (core, reusable, service, automation)
└── scripts/                    # operational automation scripts
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Core infra orchestration | `100-pve/main.tf` | Hub workspace. Pulls hosts inventory and renders configs. |
| Host inventory SoT | `100-pve/envs/prod/hosts.tf` | Single source for internal host IP/port metadata. |
| Generated config rules | `100-pve/configs/AGENTS.md` | Rendered outputs are generated-only; no manual edits. |
| Proxmox module behavior | `modules/proxmox/` | LXC, VM, lxc-config, vm-config, config-renderer. |
| Proxmox LXC module internals | `modules/proxmox/lxc/AGENTS.md` | Container lifecycle, validation, and provider constraints. |
| Proxmox VM module internals | `modules/proxmox/vm/AGENTS.md` | VM clone/cloud-init boundaries and validation rules. |
| Proxmox config rendering hub | `modules/proxmox/config-renderer/AGENTS.md` | Generated config pipeline contract and output rules. |
| Proxmox deploy modules | `modules/proxmox/lxc-config/AGENTS.md`, `modules/proxmox/vm-config/AGENTS.md` | SSH deploy orchestration, health checks, and generated artifacts. |
| Shared modules | `modules/shared/` | Cross-stack reusable modules (`onepassword-secrets`). |
| Shared 1Password details | `modules/shared/onepassword-secrets/AGENTS.md` | Item schema, output contract, and test-safe lookup pattern. |
| CI topology (overview) | `.github/AGENTS.md` | Runner, risk tiers, reusable workflow usage. |
| CI workflow details | `.github/workflows/AGENTS.md` | Pairing rules, `_terraform-*` templates, drift matrix. |
| CI custom actions | `.github/actions/AGENTS.md` | Composite action contracts (`terraform-setup`, `notify-failure`). |
| Self-hosted runner | `101-runner/AGENTS.md` | GitHub Actions runner on LXC 101; multi-repo registration. |
| Reverse proxy | `102-traefik/AGENTS.md` | Traefik ingress, TLS, MCP resilient middleware. |
| Observability stack | `104-grafana/AGENTS.md` | Prometheus + Grafana dashboards + TF-managed alerts. |
| Logging stack | `105-elk/AGENTS.md` | Elasticsearch + Logstash + Kibana; ILM policies. |
| Error tracking | `106-glitchtip/AGENTS.md` | GlitchTip (Sentry alternative) on LXC 106. |
| Supabase service | `107-supabase/AGENTS.md` | Self-hosted Supabase (PostgreSQL, Auth, Realtime). |
| Archon AI | `108-archon/AGENTS.md` | AI knowledge management + MCP server on LXC 108. |
| MCPHub gateway | `112-mcphub/AGENTS.md` | Unified MCP gateway; `mcp_servers.json` SSoT. |
| MCP catalog validation | `112-mcphub/validate_mcps.py` | Validates schema, port uniqueness, secret-pattern leaks. |
| OpenCode pipeline | `200-oc/AGENTS.md` | Dev VM + OpenCode config generation pipeline. |
| OpenCode gen details | `200-oc/opencode/AGENTS.md` | Python generator: config.py → 3 config variants. |
| OpenCode generator internals | `200-oc/opencode/gen/AGENTS.md` | Model resolution and generated output contract. |
| Synology NAS | `215-synology/AGENTS.md` | Physical NAS inventory host (not TF-provisioned). |
| Staging VM | `220-staging/AGENTS.md` | Ephemeral development sandbox with WARP. |
| Cloudflare infra | `300-cloudflare/AGENTS.md` | External infra conventions + Worker boundaries. |
| Worker-specific rules | `300-cloudflare/workers/synology-proxy/AGENTS.md` | Route/auth/cache implementation constraints. |
| Cloudflare automation scripts | `300-cloudflare/scripts/AGENTS.md` | Secret collection/sync/audit/deploy script governance. |
| GitHub org management | `301-github/AGENTS.md` | 17 repos, rulesets, webhooks, environments. |
| Test harness overview | `tests/AGENTS.md` | Native `terraform test` conventions and layout. |
| Proxmox tests | `tests/modules/proxmox/AGENTS.md` | Mock provider patterns, fixture discipline. |
| Shared module tests | `tests/modules/shared/AGENTS.md` | onepassword module test and mock rules. |
| Integration tests | `tests/integration/AGENTS.md` | Config pipeline end-to-end test strategy. |
| Workspace tests | `tests/workspaces/AGENTS.md` | Workspace variable-validation test strategy. |
| Operational docs | `docs/AGENTS.md` | Runbooks, token rotation, backup strategy. |
| Utility scripts | `scripts/AGENTS.md` | Production verification, PR automation, drift check. |

## CONVENTIONS
- Build governance: every source directory keeps `BUILD.bazel` + `OWNERS`.
- Layout: flat `{NNN}-{svc}/` directories; `modules/{provider}/` + `modules/shared/`.
- Numbering: `1-255` internal (`192.168.50.{NNN}`), `300+` external providers.
- Paths: use relative module sources (`../modules/{provider}/{module}`), no absolute/local-only shortcuts.
- SSoT: `hosts.tf` for host inventory; `112-mcphub/mcp_servers.json` for MCP server catalog.
- Generated pipeline: templates and inventories feed `module.config_renderer` to produce `100-pve/configs/...`.
- CI model: 3 core workflows + 2 reusable `_terraform-*` workflows + service plan/apply pairs + automation workflows.
- Secrets: inject via env/GitHub secrets/1Password service account; keep placeholders in tracked config.

## ANTI-PATTERNS (THIS PROJECT)
- NEVER hand-edit Terraform-rendered outputs under `100-pve/configs/` or service `tf-configs/` directories.
- NEVER hardcode IPs in workspace logic; route through `module.hosts` inventory.
- NEVER perform manual Terraform state edits outside Terraform CLI workflows.
- NEVER commit `.env`, `.tfvars`, `.tfstate`, API keys, or runtime secret dumps.
- NEVER use `as any`, `@ts-ignore`, `@ts-expect-error`, or empty catch blocks.
- NEVER SSH directly into Terraform-managed LXCs for config mutation; use IaC or `pct exec` for diagnostics only.

## COMMANDS
```bash
make plan SVC=pve
make apply SVC=pve
make plan SVC=cloudflare
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
- Service scopes: `101-runner/AGENTS.md`, `102-traefik/AGENTS.md`, `104-grafana/AGENTS.md`, `105-elk/AGENTS.md`, `106-glitchtip/AGENTS.md`, `107-supabase/AGENTS.md`, `108-archon/AGENTS.md`, `112-mcphub/AGENTS.md`
- Dev/staging scopes: `200-oc/AGENTS.md`, `200-oc/opencode/AGENTS.md`, `200-oc/opencode/gen/AGENTS.md`, `215-synology/AGENTS.md`, `220-staging/AGENTS.md`
- External scopes: `300-cloudflare/AGENTS.md`, `300-cloudflare/scripts/AGENTS.md`, `300-cloudflare/workers/AGENTS.md`, `300-cloudflare/workers/synology-proxy/AGENTS.md`, `301-github/AGENTS.md`
- Operational scopes: `docs/AGENTS.md`, `scripts/AGENTS.md`

## NOTES
- Risk-tier merge policy: critical and medium paths require manual merge; low-risk paths can auto-merge.
- Self-hosted runner (101) is required for Terraform workflows with homelab network dependencies.
- n8n webhook workflows must be published via UI after import.
