# PROJECT KNOWLEDGE BASE

**Generated:** 2026-03-24
**Commit:** _(auto-updated on push)_
**Branch:** master

## OVERVIEW

Homelab infrastructure-as-code monorepo. Provisions Proxmox LXC/VM fleet, networking, monitoring, and external services via Terraform workspaces with 1Password secret injection and GitLab CI/CD.

- **Domain**: `jclee.me` — **Subnet**: `192.168.50.0/24`
- **Terraform**: 1.10.5 (`>= 1.7, < 2.0`)
- **21 workspaces**: numeric prefix (`80` physical, `100s` Proxmox infra, `200s` VMs, `300s` external, `400s` cloud)
- **6 modules**: `modules/proxmox/{lxc,vm,lxc-config,vm-config,config-renderer}`, `modules/shared/onepassword-secrets`

## STRUCTURE

```text
terraform/
├── 100-pve/                  # Tier 0: Central orchestrator (all LXC/VM lifecycle)
│   ├── envs/prod/hosts.tf    # SSoT: all host IPs, VMIDs, roles, ports
│   └── configs/              # Rendered outputs (NEVER hand-edit)
├── 10x-{svc}/                # Tier 1 infra: traefik, coredns, elk, supabase, archon
├── 11x-{svc}/                # Tier 1 infra: n8n, mcphub
├── 2xx-{svc}/                # VM-based apps: oc, synology, youtube
├── 3xx-{svc}/                # External: cloudflare, github, safetywallet, slack
├── 400-gcp/                  # Google Cloud Platform
├── modules/
│   ├── proxmox/{lxc,vm,lxc-config,vm-config,config-renderer}/
│   └── shared/onepassword-secrets/
├── tests/                    # terraform test: unit, integration, workspace
├── scripts/                  # Go operational tooling (14 scripts, stdlib-only)
├── docs/                     # Architecture docs, ADRs, runbooks
├── .gitlab/ci/               # CI/CD pipeline definitions (7 stages)
├── ARCHITECTURE.md           # Full architecture reference
├── DEPENDENCY_MAP.md         # Module dependency graph + template inventory
└── CODE_STYLE.md             # Naming, file org, variable, template conventions
```

## WHERE TO LOOK

| Task | Location |
| ---- | -------- |
| Add new LXC/VM | `100-pve/locals.tf` (sizing) + `envs/prod/hosts.tf` (host entry) |
| Modify service config | `{NNN}-{svc}/templates/*.tftpl` → rendered by `100-pve` |
| Add/rotate secret | `modules/shared/onepassword-secrets/main.tf` + 1Password vault |
| New Traefik route | `102-traefik/templates/*.yml.tftpl` |
| ELK pipeline | `105-elk/templates/logstash.conf.tftpl` |
| Cloudflare DNS/tunnel | `300-cloudflare/main.tf` |
| GitHub repo management | `301-github/main.tf` |
| Module development | `modules/proxmox/` or `modules/shared/` |
| CI/CD workflows | `.github/workflows/` |
| Architecture decisions | `docs/adr/` (append-only, supersede with new ADR) |
| Debug/runbooks | `docs/runbooks/` |

## CONVENTIONS

### Workspace Tiers

| Tier | Workspaces | Apply Order |
| ---- | ---------- | ----------- |
| 0 (core) | `100-pve` | First — provisions all LXC/VM |
| 1 (infra) | `102-traefik`, `105-elk`, `108-archon` | Second (parallel) — consume `remote_state` from 100-pve |
| Independent | `300-cloudflare`, `301-github`, `320-slack`, `400-gcp` | Any order — no Proxmox dependency |
| Template-only | 10 workspaces | No `.tf` files — templates rendered by 100-pve |

### Config Pipeline

```
hosts.tf (SSoT) → module.hosts → onepassword_secrets + config_renderer
  → templatefile(.tftpl) → configs/ → SSH deploy to /opt/{service}/
```

### State Management

Local backend. `.tfstate` committed to git. CI concurrency groups serialize applies.

### Secret Handling

1Password vault `homelab` (12 items, 48 keys) → `onepassword-secrets` module.
Access: `module.onepassword_secrets.secrets["key"]`. Connect server: LXC 112:8090.
Sync to GitHub: `go run scripts/sync-vault-secrets.go`.

### Key Conventions

- `snake_case` for all TF identifiers. `kebab-case` for template/script files.
- Single-instance resources: `resource "x" "this"`. Multi-instance: descriptive name.
- All IPs via `module.hosts.hosts[name].ip` — never hardcode.
- All actions SHA-pinned: `uses: org/action@sha # vN`.
- Conventional commits: `type(scope): summary` (≤72 chars). Squash merge only.

## ANTI-PATTERNS

- **NO** hand-editing `configs/` — regenerate via `terraform apply`
- **NO** local `make apply` — disabled; deploy via CI/CD only
- **NO** hardcoded IPs — use `module.hosts` or variables
- **NO** committing `.tfvars`, `.env`, or API keys
- **NO** mutable GitHub Action tags (`@v4`) — SHA-pin all actions
- **NO** manual Proxmox UI changes — Terraform-managed only
- **NO** inline cloud-init — use external `.tftpl` templates
- **NO** direct resource duplication — use modules

## COMMANDS

```bash
make plan SVC=pve         # terraform plan (aliases: pve, elk, cloudflare, etc.)
make fmt                  # format all .tf files
make validate SVC=pve     # terraform validate
make lint                 # all linters (yaml, tf fmt, go vet, tflint)
make test                 # all terraform tests (unit + integration + workspace)
make test-unit            # module unit tests only
make verify               # production verification (Go script)
make backup               # encrypted tfstate backup
make setup                # load 1Password credentials locally
make docs                 # generate module README.md via terraform-docs
make security             # tflint + checkov security scan
```

17 workspace aliases: `jclee pve runner traefik elk supabase archon n8n mcphub oc synology youtube cloudflare github safetywallet slack gcp`

## Review guidelines

- Enforce conventional commit format: `type(scope): summary`.
- All GitHub Actions SHA-pinned with `# vN` comment — flag mutable tags.
- Verify no hardcoded IPs — must use `module.hosts` or variables.
- Verify no secrets in `.tf`/`.tftpl` files — use 1Password + env vars.
- Never approve hand-edits to `configs/` directories.
- PR size ~200 LOC max. Flag PRs exceeding 400 LOC.
- Squash merge only — flag merge commits.
- For module changes: verify backward-compatible variable additions.
- For template changes: verify `templatefile()` syntax and variable references.

## NOTES

- **Sync conflict**: This file is in `qws941/.github` sync list and will be overwritten on next sync push. Update `.github/sync.yml` to exclude AGENTS.md for this repo if repo-specific content must persist.
- Full architecture details: `ARCHITECTURE.md`. Module dependency graph: `DEPENDENCY_MAP.md`. Code conventions: `CODE_STYLE.md`.
- Subdirectory AGENTS.md files exist in all workspaces, modules, scripts, docs, tests, and .github — see child directories for context-specific guidance.
- CI runner: GitLab shared runners + self-hosted on LXC 101 for Proxmox. PR → plan, merge → apply. Drift detection Mon–Fri 00:00 UTC via scheduled pipelines.
- 52 `.tftpl` template files across 10 service workspaces, rendered centrally by `100-pve/config_renderer`.
