# PROJECT KNOWLEDGE BASE

**Generated:** 2026-06-29
**Commit:** 773dcd1
**Branch:** master

## OVERVIEW
Homelab infrastructure-as-code monorepo for `jclee.me`. Terraform provisions Proxmox LXC/VM fleet resources, generated service configs, Cloudflare/GitHub-style external integrations, and validation tooling with 1Password-backed secrets and GitHub Actions CI/CD.

- **Domain:** `jclee.me`
- **Subnet:** `192.168.50.0/24`
- **Terraform:** 1.10.5 (`>= 1.7, < 2.0`)
- **Workspaces:** numeric prefixes; Make aliases resolve nested `terraform/` roots where used
- **Module entry points:** 10 under `modules/{proxmox,shared,cloudflare,elasticstack}`

## STRUCTURE
```text
terraform/
├── 80-jclee/                 # Personal workstation skeleton
├── 100-pve/                  # Tier 0 Proxmox orchestrator and host SSoT
├── 101-runner/               # Template-only GitHub Actions runner config
├── 102-traefik/              # Tier 1 reverse proxy Terraform + route templates
├── 103-coredns/              # Template-only split DNS config
├── 105-elk/                  # Tier 1 ELK Terraform, templates, scripts
├── 112-mcphub/               # Template-only MCP Hub + 1Password Connect assets
├── 200-oc/ 215-synology/ 220-youtube/
├── 300-cloudflare/           # Independent Cloudflare Terraform, scripts, Workers
├── 310-safetywallet/ 400-gcp/
├── modules/                  # Terraform modules; see child AGENTS files
├── tests/                    # terraform test suites; see child AGENTS files
├── scripts/                  # Go operational tooling
├── docs/                     # Architecture docs, ADRs, runbooks
└── .github/                  # CI/CD, PR automation, issue automation
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Add or resize LXC/VM | `100-pve/terraform/locals.tf` + `100-pve/envs/prod/hosts.tf` | `hosts.tf` is the host/IP/VMID SSoT. |
| Change service config | `{NNN}-{svc}/templates/*.tftpl` | Rendered centrally by `100-pve`; never edit outputs. |
| New Traefik route | `102-traefik/templates/*.yml.tftpl` | Backend IPs from host map/template vars only. |
| ELK pipeline/indexing | `105-elk/templates/logstash.conf.tftpl` + `modules/elasticstack/` | Keep ILM and auth assumptions intact. |
| Cloudflare DNS/tunnel/Access | `300-cloudflare/terraform/` + `modules/cloudflare/` | Scripts and Workers have separate child scopes. |
| Secret retrieval | `modules/shared/onepassword-secrets/` | Values come from 1Password, not committed files. |
| CI/CD or PR policy | `.github/AGENTS.md` + `.github/workflows/` | Many workflows delegate to `jclee941/.github`. |
| Test behavior | `tests/AGENTS.md` | Native `terraform test`; provider-mocked by default. |
| Documentation policy | `docs/AGENTS.md` | ADRs append-only; runbooks actionable. |

## CODE MAP
| Symbol / Entry | Type | Location | Role |
|----------------|------|----------|------|
| `main.tf` | Terraform root | `100-pve/terraform/main.tf` | Core Proxmox module wiring. |
| `hosts.tf` | Terraform SSoT | `100-pve/envs/prod/hosts.tf` | Host IPs, VMIDs, roles, ports. |
| `main.tf` | Terraform root | `102-traefik/terraform/main.tf` | Tier 1 ingress workspace. |
| `main.tf` | Terraform root | `105-elk/terraform/main.tf` | Tier 1 Elastic provider workspace. |
| `main.tf` | Terraform root | `215-synology/main.tf` | Flat workspace exception. |
| `main.tf` | Terraform root | `300-cloudflare/terraform/main.tf` | External Cloudflare workspace. |
| `proxmox/*/main.tf` | Module entries | `modules/proxmox/` | LXC/VM/firewall/config rendering. |
| `cloudflare/tunnel/main.tf` | Module entry | `modules/cloudflare/tunnel/` | Reusable Cloudflare tunnel module. |
| `elasticstack/*/main.tf` | Module entries | `modules/elasticstack/` | ILM policy and index template helpers. |
| `main()` | Go CLI | `scripts/validate-docs/main.go` | Docs lint harness behind `make lint-docs`. |
| `main()` | Go CLI | `300-cloudflare/scripts/collect.go` | Secret-bearing tfvars/env collection; emits DO NOT COMMIT output. |

## CONVENTIONS
- Active Terraform workspaces usually keep `.tf` files under `{workspace}/terraform/`; `215-synology/` is the flat exception.
- `make` aliases are the command contract: `pve`, `traefik`, `elk`, `synology`, `cloudflare`, `gcp`, etc.
- `snake_case` for Terraform identifiers; single-instance resources use `resource "x" "this"`.
- Templates and scripts use `kebab-case`; app logic belongs in `templates/*.tftpl`, not inline cloud-init.
- Variables and outputs need descriptions; variables need explicit types.
- Local backend state exists beside workspaces. CI concurrency is the serialization mechanism.
- 1Password vault `homelab` feeds Terraform via the shared module and environment variables.

## ANTI-PATTERNS
- No local `make apply` or local drift check; deployment and drift detection are CI/CD paths.
- No hand-editing `100-pve/configs/`, `tf-configs/`, rendered templates, or guest files managed by Terraform.
- No hardcoded service IPs; use `module.hosts.hosts[name].ip`, variables, or template inputs.
- No committed `.tfvars`, `.env`, API keys, tunnel tokens, private keys, or secret-bearing `data/` outputs.
- No mutable GitHub Action tags when adding or reviewing workflow dependencies; existing workflows still contain mixed tag pinning.
- No manual Proxmox UI changes for Terraform-managed guests.
- No direct resource duplication in workspaces when a local module owns the abstraction.

## COMMANDS
```bash
make plan SVC=pve
make fmt
make validate SVC=pve
make lint
make lint-docs
make test
make test-unit
make test-integration
make test-workspace
make verify
make backup
make setup
make docs
make security
```

## NOTES
- LSP is available for Go/TypeScript/Terraform in this environment; no `codegraph_*` tool was exposed during this run.
