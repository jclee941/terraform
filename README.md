# Homelab Infrastructure Monorepo / 홈랩 인프라 모노레포

> **Manual `apply` is disabled. All changes deploy through CI/CD.**
> **수동 `apply`는 비활성화되어 있습니다. 모든 변경 사항은 CI/CD를 통해 배포됩니다.**

A monorepo of self-contained infrastructure-as-code (IaC) workspaces for a personal homelab and a small set of external (cloud) integrations. Every workspace follows a flat `NNN-SERVICE` naming convention and is managed through a single top-level `Makefile`. All secrets are injected from 1Password at apply-time; production deploys flow exclusively through GitHub Actions.

개인 홈랩과 소규모 외부(클라우드) 통합을 위한 독립형 인프라스트럭처-코드(IaC) 워크스페이스 모노레포입니다. 모든 워크스페이스는 `NNN-SERVICE` 명명 규칙을 따르며, 최상위 `Makefile` 하나로 전체 워크스페이스를 제어합니다. 비밀 값은 모두 1Password에서 적용 시점(apply-time)에 주입되며, 프로덕션 배포는 GitHub Actions를 통해서만 진행됩니다.

---

## Table of Contents / 목차

- [Overview / 개요](#overview--개요)
- [Features / 주요 기능](#features--주요-기능)
- [Architecture / 아키텍처](#architecture--아키텍처)
- [Repository Layout / 저장소 구성](#repository-layout--저장소-구성)
- [Workspaces / 워크스페이스](#workspaces--워크스페이스)
- [Numbering Convention / 번호 규칙](#numbering-convention--번호-규칙)
- [Quick Start / 빠른 시작](#quick-start--빠른-시작)
- [Configuration / 설정](#configuration--설정)
- [Commands Reference / 명령어 참조](#commands-reference--명령어-참조)
- [Local Development / 로컬 개발](#local-development--로컬-개발)
- [Testing / 테스트](#testing--테스트)
- [Contributing / 기여 방법](#contributing--기여-방법)
- [License / 라이선스](#license--라이선스)
- [Additional Documentation / 추가 문서](#additional-documentation--추가-문서)

---

## Overview / 개요

This repository hosts the infrastructure code that provisions the homelab fleet (Proxmox LXC/VM) and a small set of satellite external integrations (Cloudflare DNS/Access/Logpush, ELK observability, MCPHub tooling, CoreDNS service discovery, MCP servers for 1Password, etc.). It contains **no application source code** — only manifests, Terraform modules, Go helper scripts, Python validators, Node.js MCP shims, Dockerfiles, Docker Compose stacks, and templates required to deploy them.

이 저장소는 홈랩 플릿(Proxmox LXC/VM)과 위성 외부 통합(Cloudflare DNS/Access/Logpush, ELK 관측성, MCPHub 도구, CoreDNS 서비스 디스커버리, 1Password용 MCP 서버 등)을 프로비저닝하는 인프라 코드를 호스팅합니다. **애플리케이션 소스는 포함하지 않으며**, 배포에 필요한 매니페스트, Terraform 모듈, Go 보조 스크립트, Python 검증기, Node.js MCP 셰임, Dockerfile, Docker Compose 스택과 템플릿만 포함합니다.

Three workspace flavors are supported:

| Flavor / 종류 | Purpose / 용도 | Marker / 표식 |
| --- | --- | --- |
| **Terraform workspace** | Full IaC with `main.tf`, `providers.tf`, `outputs.tf`, etc. | `*.tf` files at workspace root or under a `terraform/` subdir |
| **Template-only workspace** | Only `*.tftpl` files; rendered by the Tier 0 orchestrator into per-host configs | No `*.tf`; output lands in `configs/` via `templatefile()` |
| **Configuration bundle** | Dockerfiles, runtime patches, helper scripts, MCP servers | `config/`, `patches/`, `scripts/`, `op-mcp-server/` |

The default Make target is `SVC=100-pve` (the Tier 0 orchestrator). Choose any workspace with `SVC=<alias or numeric path>`.

Makefile의 기본 대상은 `SVC=100-pve`(Tier 0 오케스트레이터)입니다. `SVC=<별칭 또는 숫자 경로>`로 워크스페이스를 전환할 수 있습니다.

---

## Features / 주요 기능

- **Flat workspace naming** — `NNN-SERVICE` directory convention with three-digit numeric prefixes for predictable ordering and clear scope.
- **Single Makefile entry point** — every workspace shares the same `init`, `plan`, `fmt`, `validate`, `lint`, `lint-go`, `drift-check`, `test`, `docs`, and `help` targets.
- **1Password secret injection** — secrets are pulled from the `homelab` vault via the shared `onepassword-secrets` module at apply-time; no plaintext secret values live in this repository.
- **Manual apply disabled by design** — local `make apply` refuses to run; production deploys flow only through GitHub Actions.
- **Template renderer** — `*.tftpl` files are rendered per host into `configs/` and SSH-deployed to `/opt/<service>/`.
- **Go stdlib-only helpers** — operational scripts (`setup-ilm.go`, `setup-watcher.go`, `remove-promtail.go`, `entrypoint-patch.go`, etc.) deliberately avoid third-party dependencies.
- **Multi-language config tooling** — Python for static MCP validation, Node.js ESM for the 1Password MCP shim, Bash for entrypoints.
- **Bilingual documentation** — top-level docs and READMEs ship in Korean and English.

---

## Architecture / 아키텍처

The repository is organized into tiers based on dependency relationships and apply order. The root `Makefile` is the single entry point: it resolves the workspace path through `SVC=NNN-SVC` (or a short alias) and dispatches to Terraform, Go, pre-commit, and shell tooling.

### Workspace Tiers / 워크스페이스 계층

| Tier / 계층 | Role / 역할 | Apply Order / 적용 순서 |
| --- | --- | --- |
| 0 — Core orchestrator | Provisions all LXC/VM lifecycle for the homelab | First |
| 1 — Infrastructure | Traefik ingress, ELK observability, CoreDNS, MCPHub, etc. | Second (parallel where safe) |
| Independent | External services such as Cloudflare DNS/Access/Logpush, GitHub, Slack, GCP | Any order; no Proxmox dependency |
| Template-only | Workspaces that publish only `*.tftpl` files | Rendered by Tier 0 |

### Build & Deploy Flow (Numbered) / 빌드·배포 흐름

1. **Operator edits code** — a change is pushed to `master` or opened as a PR.
2. **GitHub Actions triggers CI** — `fmt`, `validate`, `lint`, `drift-check`, and `test` jobs run against the affected workspace(s).
3. **Make resolves workspace** — `SVC=<alias>` resolves to a numeric workspace path; `check_svc_dir` validates that the directory exists.
4. **Terraform init/plan** — `make init SVC=<ws>` and `make plan SVC=<ws>` produce a saved plan file.
5. **1Password secrets resolved** — the `onepassword-secrets` module reads values from the `homelab` vault at apply-time.
6. **Apply (CI only)** — `make apply` is intentionally disabled locally; the GitHub Actions runner executes `terraform apply tfplan`.
7. **Config renderer** — for template-only workspaces, the Tier 0 orchestrator uses `templatefile()` to materialize per-host files under `configs/`.
8. **SSH deploy** — rendered configs are placed under `/opt/<service>/` on each target LXC/VM.

### ELK Data Flow (Numbered) / ELK 데이터 흐름

1. **Logs** — Docker containers on each LXC/VM emit to stdout/stderr.
2. **Shippers** — Filebeat (per-host, configured by `filebeat.yml`) tails Docker log files.
3. **Pipeline** — Logstash (`logstash.conf` + `logstash.yml`, custom `Dockerfile.logstash`) parses and enriches events.
4. **Storage** — Elasticsearch stores logs under an Index Lifecycle Management policy (`ilm-policy.json`) installed by `setup-ilm.go` on first boot.
5. **Search** — Kibana dashboards and queries run against the rolling indices.
6. **Maintenance** — `setup-watcher.go` detects ILM drift; `remove-promtail.go` cleans up the legacy Promtail agent during a Filebeat migration.

### Component Overview / 컴포넌트 개요

| Component / 컴포넌트 | Path | Responsibility / 책임 |
| --- | --- | --- |
| Makefile | `/Makefile` | Resolves `SVC` → workspace path; dispatches to Terraform, Go, pre-commit, helpers |
| 1Password secrets | `onepassword-secrets` shared module | Pulls vault items at apply-time |
| Traefik ingress | `102-traefik/terraform/` | LXC reverse proxy + routing |
| CoreDNS discovery | `103-coredns/templates/` | Cluster-internal service discovery |
| ELK observability | `105-elk/terraform/` | Elasticsearch + Logstash + Kibana + Filebeat |
| MCPHub aggregation | `112-mcphub/` | MCP server catalog + Dockerfiles + 1Password MCP shim |
| Cloudflare edge | `300-cloudflare/` | DNS, Access applications/policies, Logpush, identity provider |

---

## Repository Layout / 저장소 구성

The tree below reflects the actual contents of this repository at the time of writing.

```text
.
├── AGENTS.md                      # Machine-readable project knowledge base (tiers, conventions)
├── ARCHITECTURE.md                # Long-form architecture narrative
├── CODE_STYLE.md                  # Terraform / Go / template conventions
├── CONTRIBUTING.md                # Contribution guidelines
├── DEPENDENCY_MAP.md              # Module dependency graph + template inventory
├── LICENSE                        # Repository license
├── Makefile                       # Single entry point (SVC=NNN-SVC selector)
├── OWNERS                         # Ownership table
├── OWNERS_ALIASES                 # Ownership aliases
├── build.env                      # Build-time environment defaults (sourced by tools)
├── README.md                      # This file (Korean + English)
├── 103-coredns/                   # CoreDNS service discovery (template bundle)
│   ├── AGENTS.md
│   ├── README.md
│   └── templates/
│       ├── AGENTS.md
│       ├── Corefile.tftpl
│       ├── docker-compose.yml.tftpl
│       └── filebeat.yml.tftpl
├── 105-elk/                       # ELK observability stack
│   ├── AGENTS.md
│   ├── docker-compose.yml
│   ├── ilm-policy.json
│   ├── scripts/
│   │   ├── remove-promtail        # Bash entrypoint
│   │   ├── remove-promtail.go     # Cleans up old Promtail during Filebeat migration
│   │   ├── setup-ilm.go           # Installs the ILM policy on first boot
│   │   └── setup-watcher.go       # Watches ILM state for drift
│   ├── config/
│   │   ├── AGENTS.md
│   │   ├── Dockerfile.logstash
│   │   ├── filebeat.yml
│   │   ├── ilm-policy.json
│   │   ├── logstash.conf
│   │   └── logstash.yml
│   ├── templates/
│   │   ├── AGENTS.md
│   │   ├── Dockerfile.logstash.tftpl
│   │   ├── docker-compose.yml.tftpl
│   │   ├── filebeat.yml.tftpl
│   │   ├── ilm-policy.json.tftpl
│   │   ├── logstash.conf.tftpl
│   │   ├── logstash.yml.tftpl
│   │   └── setup-ilm.sh.tftpl
│   └── terraform/
│       ├── AGENTS.md
│       ├── README.md
│       ├── checks.tf              # Pre/post conditions
│       ├── main.tf
│       ├── onepassword.tf         # 1Password secret reads
│       ├── outputs.tf
│       ├── providers.tf
│       ├── validation.tf          # Variable validation blocks
│       ├── variables.tf
│       └── versions.tf
├── 112-mcphub/                    # MCPHub + 1Password MCP server
│   ├── AGENTS.md
│   ├── Dockerfile.dev-browser     # Browser image (dev profile)
│   ├── Dockerfile.playwright      # Playwright image for MCP
│   ├── Dockerfile.proxmox         # Proxmox MCP image
│   ├── README.md
│   ├── mcp_servers.json           # MCP server catalog (validated)
│   ├── validate_mcps.py           # Static validator for mcp_servers.json
│   ├── patches/
│   │   └── n8n/
│   │       ├── license-state.js   # n8n license-state runtime patch
│   │       └── license.js         # n8n license runtime patch
│   ├── op-mcp-server/             # 1Password MCP integration (Node.js ESM)
│   │   ├── AGENTS.md
│   │   ├── index.mjs
│   │   ├── package-lock.json
│   │   └── package.json
│   ├── config/
│   │   ├── AGENTS.md
│   │   ├── entrypoint-patch.go    # Runtime entrypoint patcher
│   │   ├── filebeat.yml
│   │   ├── patch-placeholder.cjs  # Placeholder substitution for bundled configs
│   │   └── patch-sdk-schema.cjs   # Patches the MCP SDK schema at build time
│   └── templates/
│       ├── AGENTS.md
│       ├── docker-compose-op-connect.yml.tftpl
│       ├── docker-compose.yml.tftpl
│       ├── filebeat.yml.tftpl
│       └── mcp_settings.json.tftpl
└── 300-cloudflare/                # Cloudflare DNS / Access / Logpush
    ├── AGENTS.md
    ├── README.md
    ├── access.tf                  # Cloudflare Access applications + policies
    ├── checks.tf                  # Drift/checks
    ├── dns.tf                     # DNS records
    ├── identity-provider.tf       # Org-level identity provider config
    ├── locals.tf                  # Local values (zones, hosts, etc.)
    ├── logpush.tf                 # Logpush jobs
    ├── main.tf                    # Provider + module wiring
    ├── onepassword.tf             # API tokens from 1Password
    ├── outputs-homelab.tf         # Outputs for homelab consumers
    ├── outputs-jclee.tf           # Outputs for personal-domain consumers
    ├── outputs-synology.tf        # Outputs for Synology consumers
    └── outputs.tf                 # General outputs
```

---

## Workspaces / 워크스페이스

This section covers the workspaces shipped in this snapshot. Each workspace is identified by a short alias you can pass to `make` as `SVC=<alias>` (see the [Makefile Alias Map](#makefile-alias-map--makefile-별칭-맵) below).

### Visible Workspaces / 실제로 포함된 워크스페이스

| SVC / 식별자 | Alias / 별칭 | Flavor / 종류 | Description / 설명 |
| --- | --- | --- | --- |
| `103-coredns` | (use numeric path) | Template-only | CoreDNS-based service discovery. Publishes `Corefile.tftpl`, `docker-compose.yml.tftpl`, and `filebeat.yml.tftpl` for the Tier 0 orchestrator to render per cluster. |
| `105-elk` | `elk` | Terraform workspace + config bundle | Full ELK stack — Elasticsearch + Logstash + Kibana + Filebeat. Includes Terraform under `terraform/`, Go setup scripts, ILM policy, and per-host logstash config templates. |
| `112-mcphub` | `mcphub` | Configuration bundle | MCPHub orchestration: aggregates MCP servers, ships dedicated Dockerfiles (`dev-browser`, `playwright`, `proxmox`), bundles a Node.js 1Password MCP shim, validates `mcp_servers.json`, and provides runtime patches (including an `n8n` license-state patcher). |
| `300-cloudflare` | `cloudflare` | Terraform workspace | External Cloudflare workspace — DNS records, Access applications & policies, Logpush jobs, identity provider config, and per-consumer output files (`homelab`, `jclee`, `synology`). |

### Makefile Alias Map / Makefile 별칭 맵

The Makefile defines short aliases that resolve to the canonical workspace path. Both the full path and the alias are accepted by `make <target>`.

| Alias / 별칭 | Workspace Path / 워크스페이스 경로 |
| --- | --- |
| `jclee` | `80-jclee` |
| `pve` | `100-pve` |
| `runner` | `101-runner` |
| `traefik` | `102-traefik/terraform` |
| `elk` | `105-elk/terraform` |
| `supabase` | `107-supabase` |
| `archon` | `108-archon/terraform` |
| `n8n` | `110-n8n` |
| `mcphub` | `112-mcphub` |
| `oc` | `200-oc` |
| `synology` | `215-synology` |
| `youtube` | `220-youtube` |
| `cloudflare` | `300-cloudflare` |
| `github` | `301-github` |
| `safetywallet` | `310-safetywallet` |
| `slack` | `320-slack` |
| `gcp` | `400-gcp` |

If you pass an `SVC` that does not resolve to a local directory, `make` aborts early and prints both the direct numeric directories it found and the alias table above.

`SVC`가 로컬 디렉터리로 해석되지 않으면 `make`는 조기 중단하며, 디스크에 존재하는 숫자 디렉터리와 위 별칭 표를 함께 출력합니다.

---

## Numbering Convention / 번호 규칙

The flat `NNN-SERVICE` prefix is meaningful: it communicates scope and apply order at a glance.

| Range / 구간 | Scope / 범위 | Examples / 예시 |
| --- | --- | --- |
| `001`–`099` | Hosts / physical | `80-jclee` |
| `100`–`199` | Proxmox infrastructure | `100-pve` (orchestrator), `101-runner`, `102-traefik`, `103-coredns`, `105-elk`, `107-supabase`, `108-archon`, `110-n8n`, `112-mcphub` |
| `200`–`299` | VM-based applications | `200-oc`, `215-synology`, `220-youtube` |
| `300`–`399` | External SaaS | `300-cloudflare`, `301-github`, `310-safetywallet`, `320-slack` |
| `400`+ | Cloud providers | `400-gcp` |

---

## Quick Start / 빠른 시작

### Prerequisites / 사전 요구 사항

| Tool / 도구 | Min. version / 최소 버전 | Notes / 비고 |
| --- | --- | --- |
| Terraform | `>= 1.7, < 2.0` | Pinned close to `1.10.5` |
| Go | `1.22+` | Stdlib-only helpers (`setup-ilm.go`, `remove-promtail.go`, etc.) |
| Node.js | `20+` | Only required for `112-mcphub/op-mcp-server/` |
| Python | `3.10+` | Only required for `112-mcphub/validate_mcps.py` |
| 1Password CLI | `2.x` | Read-time secret injection via `OP_SERVICE_ACCOUNT_TOKEN` |
| pre-commit | `3.x` | Formatting + policy hooks (`make pre-commit-install`) |
| Docker / Compose | `24+` / `v2` | Local stack validation only |

### Bootstrap / 부트스트랩

```bash
# 1. Clone the repository
git clone https://github.com/<org>/<repo>.git
cd <repo>

# 2. Install pre-commit hooks (fmt, secret scan, validators)
make pre-commit-install

# 3. Pick a workspace and initialize it
make init SVC=pve              # alias -> 100-pve
make init SVC=300-cloudflare   # full numeric path also accepted

# 4. Plan (safe locally)
make plan SVC=pve

# 5. Format + validate + lint + drift-check the touched workspaces
make fmt
make validate SVC=elk
make lint-go
make drift-check SVC=cloudflare

# 6. Apply via CI/CD only -- local `make apply` is intentionally disabled
```

---

## Configuration / 설정

### Build Defaults / 빌드 기본값

The `build.env` file exposes shared environment defaults used by helper scripts and Make includes. Source it before running local tooling:

```bash
set -a
. ./build.env
set +a
```

### Secrets / 비밀 값

| Source / 출처 | Mechanism / 메커니즘 |
| --- | --- |
| 1Password vault `homelab` | Read at Terraform apply-time via the `onepassword-secrets` module |
| Environment variables (`OP_SERVICE_ACCOUNT_TOKEN`, etc.) | Required by the 1Password provider |
| Per-workspace `onepassword.tf` | Wires Terraform variables to specific vault items |

No plaintext secret values are committed to this repository. Adding or rotating a secret requires two coordinated steps: (1) place the item in the 1Password vault under the expected reference, (2) reference it from the workspace's `onepassword.tf` and `variables.tf`.

### Terraform Variables / Terraform 변수

Each Terraform workspace declares its variables in `variables.tf` with validation enforced in `validation.tf` (e.g.