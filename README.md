# Homelab Infrastructure Monorepo / 홈랩 인프라 모노레포

> **Manual `apply` is disabled. All changes deploy through CI/CD.**
> **수동 `apply`는 비활성화되어 있습니다. 모든 변경 사항은 CI/CD를 통해 배포됩니다.**

A monorepo of self-contained infrastructure-as-code (IaC) workspaces for a personal homelab and a small set of external (cloud) integrations. Every workspace is named with a flat `NNN-SERVICE` identifier and managed through a single top-level `Makefile`.

개인 홈랩과 소규모 외부(클라우드) 통합을 위한 독립형 인프라스트럭처-코드(IaC) 워크스페이스 모노레포입니다. 각 워크스페이스는 `NNN-SERVICE` 형식의 평탄한(flat) 식별자로 명명되며, 최상위 `Makefile` 하나로 전부 제어합니다.

---

## Table of Contents / 목차

- [Overview / 개요](#overview--개요)
- [Features / 주요 기능](#features--주요-기능)
- [Architecture / 아키텍처](#architecture--아키텍처)
- [Repository Layout / 저장소 구성](#repository-layout--저장소-구성)
- [Workspaces / 워크스페이스](#workspaces--워크스페이스)
- [Numbering Convention / 번호 규칙](#numbering--규칙)
- [Workspace Tiers and Apply Order / 워크스페이스 계층과 적용 순서](#workspace-tiers-and-apply-order--워크스페이스-계층과-적용-순서)
- [Quick Start / 빠른 시작](#quick-start--빠른-시작)
- [Configuration / 설정](#configuration--설정)
- [Commands Reference / 명령어 참조](#commands-reference--명령어-참조)
- [Local Development / 로컬 개발](#local-development--로컬-개발)
- [Testing / 테스트](#testing--테스트)
- [Contributing / 기여 방법](#contributing--기여-방법)
- [Additional Documentation / 추가 문서](#additional-documentation--추가-문서)
- [License / 라이선스](#license--라이선스)

---

## Overview / 개요

This repository hosts the IaC used to run a homelab and a small set of satellite external integrations (Cloudflare DNS/Access/Logpush, ELK observability, MCPHub tooling, CoreDNS service discovery, etc.). There are **no application sources** here — only manifests, Terraform modules, templates, helper Go scripts, and Docker Compose stacks needed to deploy them.

이 저장소는 홈랩과 위성 외부 통합(Cloudflare DNS/Access/Logpush, ELK 관측성, MCPHub 도구, CoreDNS 서비스 디스커버리 등)을 운영하는 데 필요한 IaC를 한곳에 모아둔 곳입니다. 여기에는 **애플리케이션 소스는 없으며**, 배포에 필요한 매니페스트, Terraform 모듈, 템플릿, 보조 Go 스크립트, Docker Compose 스택만 포함됩니다.

Three workspace flavors are supported / 세 가지 워크스페이스 종류를 지원합니다.

| Flavor / 종류 | Purpose / 용도 | Marker / 표식 |
| --- | --- | --- |
| Terraform workspace / Terraform 워크스페이스 | Owns `.tf` files; provisions real resources / `.tf` 파일 보유, 실제 리소스 프로비저닝 | `main.tf`, `providers.tf`, `versions.tf` |
| Template-only workspace / 템플릿 전용 워크스페이스 | Pure `.tftpl` files rendered by `100-pve` / 순수 `.tftpl` 파일, `100-pve`가 렌더링 | `templates/*.tftpl` only |
| App workspace with `terraform/` subdir / `terraform/` 하위 디렉터리를 가진 앱 워크스페이스 | App sources at workspace root, Terraform nested inside / 앱 소스는 루트, Terraform은 내부에 위치 | `terraform/main.tf` |

A single root `Makefile` is the only operator entry point. Every Terraform and operational task flows through `make <target> [SVC=<workspace>]`.

루트 `Makefile` 하나가 운영자의 유일한 진입점입니다. 모든 Terraform 및 운영 작업은 `make <target> [SVC=<workspace>]` 형태로 실행됩니다.

---

## Features / 주요 기능

- **Single Makefile entry point** — One interface for `init`, `plan`, `apply` (CI/CD only), `validate`, `fmt`, `lint`, `test`, `drift-check`, `docs`, and helper scripts.
  **단일 Makefile 진입점** — `init`, `plan`, `apply`(CI/CD 전용), `validate`, `fmt`, `lint`, `test`, `drift-check`, `docs`, 헬퍼 스크립트를 하나의 인터페이스로 제공합니다.
- **Flat `NNN-SERVICE` naming** — Predictable numeric ordering for Proxmox, ingress, observability, app VMs, and external integrations.
  **평탄한 `NNN-SERVICE` 명명** — Proxmox, 인그레스, 관측성, 앱 VM, 외부 통합을 위한 예측 가능한 숫자 순서.
- **Workspace tiers** — Tier 0 (`100-pve`) provisions all LXC/VM lifecycles; Tier 1 consumes its `remote_state`; independent workspaces (Cloudflare, GitHub, Slack, GCP) run in any order.
  **워크스페이스 계층** — Tier 0(`100-pve`)가 모든 LXC/VM 생명주기를 프로비저닝하고, Tier 1은 그 `remote_state`를 소비합니다. 독립 워크스페이스(Cloudflare, GitHub, Slack, GCP)는 어떤 순서로든 실행할 수 있습니다.
- **1Password secret injection** — Centralized secret management via the shared `onepassword-secrets` module.
  **1Password 시크릿 주입** — 공유 `onepassword-secrets` 모듈을 통한 중앙화된 시크릿 관리.
- **Template-driven config rendering** — `hosts.tf` (single source of truth) feeds the `config-renderer` module, which `templatefile()`s `*.tftpl` sources into rendered configs deployed over SSH to `/opt/<service>/`.
  **템플릿 기반 설정 렌더링** — `hosts.tf`(단일 진실 공급원)가 `config-renderer` 모듈로 전달되어, `*.tftpl` 소스를 `templatefile()`로 렌더링한 뒤 SSH로 `/opt/<service>/`에 배포합니다.
- **Cross-workspace observability** — Filebeat → Logstash → Elasticsearch → Kibana with ILM, wired in `105-elk`.
  **크로스 워크스페이스 관측성** — `105-elk`에 구성된 Filebeat → Logstash → Elasticsearch → Kibana + ILM 파이프라인.
- **Bilingual docs** — All major docs (this README, `ARCHITECTURE.md`, per-workspace `AGENTS.md` / `README.md`) ship in Korean + English.
  **이중 언어 문서** — 모든 주요 문서(이 README, `ARCHITECTURE.md`, 워크스페이스별 `AGENTS.md` / `README.md`)가 한국어 + 영어로 제공됩니다.

---

## Architecture / 아키텍처

The high-level request flow / 요청 흐름 요약:

1. Operator (or AI agent) edits Terraform / templates / `hosts.tf` in this repo.
2. Push to `master` triggers GitHub Actions on the self-hosted runner LXC (`101-runner`).
3. CI/CD runs `terraform init` → `plan` → `apply` per workspace in tier order.
4. Tier 0 (`100-pve`) provisions the Proxmox LXC/VM fleet and renders per-service `*.tftpl` configs.
5. Tier 1 (`102-traefik`, `103-coredns`, `105-elk`, `108-archon`, etc.) consume `100-pve`'s `remote_state` and configure themselves.
6. Independent workspaces (`300-cloudflare`, `301-github`, `320-slack`, `400-gcp`) configure external systems.
7. ELK pipeline (`105-elk`) ingests logs from Filebeat across the fleet.

운영자(또는 AI 에이전트)가 저장소의 Terraform / 템플릿 / `hosts.tf`를 수정합니다. `master` 푸시는 셀프 호스트 러너 LXC(`101-runner`)의 GitHub Actions를 트리거하고, CI/CD가 워크스페이스별로 계층 순서대로 `init` → `plan` → `apply`를 수행합니다. Tier 0(`100-pve`)가 Proxmox LXC/VM 플릿을 프로비저닝하고 서비스별 `*.tftpl` 설정을 렌더링하며, Tier 1이 그 `remote_state`를 소비해 자신을 구성합니다.

### Runtime Roles / 런타임 역할

| Layer / 계층 | Component / 구성요소 | Location / 위치 | Responsibility / 책임 |
| --- | --- | --- | --- |
| CI/CD | GitHub Actions runner | `101-runner` LXC | Hosts runners; drives `make plan`/`apply` |
| Orchestration / 오케스트레이션 | Proxmox VE | Tier 0 host | LXC/VM lifecycle, networking, storage |
| Compute / 컴퓨트 | LXC fleet | `101`–`115` prefixes | Lightweight services (runner, traefik, coredns, elk, …) |
| Compute / 컴퓨트 | VM fleet | `200`–`299` prefixes | Heavier workloads (OC, Synology, YouTube) |
| Ingress / 인그레스 | Traefik | `102-traefik/terraform` | Reverse proxy + TLS termination |
| Discovery / 디스커버리 | CoreDNS | `103-coredns/templates` | LAN service discovery via `*.lan` |
| Observability / 관측성 | ELK stack | `105-elk/terraform` | Logs, ILM, Kibana dashboards |
| Tooling / 도구 | MCPHub | `112-mcphub` | Multi-server MCP tooling with op-Connect |
| External / 외부 | Cloudflare | `300-cloudflare` | DNS, Access, Tunnel, Logpush |
| External / 외부 | GitHub, Slack, GCP | `301-github`, `320-slack`, `400-gcp` | Repo mgmt, chat, cloud |
| App VMs / 앱 VM | oc, synology, youtube | `200-oc`, `215-synology`, `220-youtube` | Service workloads |

### Configuration Pipeline / 설정 파이프라인

```
hosts.tf (SSoT) → module.hosts → onepassword_secrets + config_renderer
  → templatefile(.tftpl) → configs/ → SSH deploy to /opt/<service>/
```

### Request Flow / 요청 흐름

1. Edit `hosts.tf` or per-service `*.tftpl` files.
2. Run `make plan SVC=<workspace>` to preview.
3. Push to `master` → CI applies the change.
4. `100-pve` (when changed) re-renders downstream configs.
5. ELK and Cloudflare observe every layer.

자세한 내용은 [ARCHITECTURE.md](./ARCHITECTURE.md)와 [DEPENDENCY_MAP.md](./DEPENDENCY_MAP.md)를 참조하세요.

---

## Repository Layout / 저장소 구성

```text
/
├── 103-coredns/              # Tier 1: CoreDNS service discovery (templates only)
│   └── templates/            # Corefile, docker-compose.yml, filebeat.yml
├── 105-elk/                  # Tier 1: ELK observability
│   ├── scripts/              # Go operational tooling (remove-promtail, setup-ilm, setup-watcher)
│   ├── config/               # Dockerfile.logstash, filebeat, ilm, logstash conf + yml
│   ├── templates/            # *.tftpl rendered by 100-pve
│   └── terraform/            # checks.tf, main.tf, onepassword.tf, outputs.tf, providers.tf, validation.tf, variables.tf, versions.tf
├── 112-mcphub/               # MCPHub tooling
│   ├── Dockerfile.dev-browser
│   ├── Dockerfile.playwright
│   ├── Dockerfile.proxmox
│   ├── mcp_servers.json
│   ├── validate_mcps.py
│   ├── patches/n8n/          # license-state.js, license.js for n8n patches
│   ├── op-mcp-server/        # Node.js 1Password Connect bridge (index.mjs, package*.json)
│   ├── config/               # entrypoint-patch.go, filebeat.yml, patch-*.cjs
│   └── templates/            # docker-compose*.yml.tftpl, filebeat.yml.tftpl, mcp_settings.json.tftpl
├── 300-cloudflare/           # External: Cloudflare DNS / Access / Tunnel / Logpush
│   └── *.tf                  # access, checks, dns, identity-provider, locals, logpush, main, onepassword, outputs(-homelab|-jclee|-synology)
├── 103-coredns/AGENTS.md     # Per-workspace AI/operator guidance
├── AGENTS.md                 # Repo-wide AI/operator guidance
├── ARCHITECTURE.md           # Architecture reference
├── CODE_STYLE.md             # Naming, file org, variable, template conventions
├── CONTRIBUTING.md           # Contribution guide
├── DEPENDENCY_MAP.md         # Module dependency graph + template inventory
├── LICENSE
├── Makefile                  # Single entry point (see Commands Reference)
├── OWNERS                    # Repo ownership roster
├── OWNERS_ALIASES            # Alias map for OWNERS
├── README.md                 # This document
└── build.env                 # Build-time environment variables
```

> The exact on-disk layout may include additional workspaces (`80-jclee`, `100-pve`, `101-runner`, `102-traefik`, `107-supabase`, `108-archon`, `110-n8n`, `200-oc`, `215-synology`, `220-youtube`, `301-github`, `310-safetywallet`, `320-slack`, `400-gcp`) and shared `modules/` (not listed above). The four directories above are what this README inspects directly.
> 실제 디스크 레이아웃에는 위에 나열되지 않은 추가 워크스페이스와 공유 `modules/` 디렉터리가 포함될 수 있습니다. 위에 표시된 네 개 디렉터리는 이 README가 직접 검사한 항목입니다.

---

## Workspaces / 워크스페이스

The four workspaces with content shipped in this tree / 이 트리에 직접 포함된 네 개 워크스페이스.

### 103-coredns (template-only) — CoreDNS LAN service discovery

| File | Purpose |
| --- | --- |
| `templates/Corefile.tftpl` | CoreDNS zone config (forwarders, `*.lan` resolution) |
| `templates/docker-compose.yml.tftpl` | Container runtime definition |
| `templates/filebeat.yml.tftpl` | Filebeat shipper config for ELK ingestion |

### 105-elk (full Terraform + scripts) — Centralized logging

| File | Purpose |
| --- | --- |
| `docker-compose.yml` | Local Compose stack used during development |
| `ilm-policy.json` | Index Lifecycle Management policy reference |
| `scripts/remove-promtail.go`, `scripts/remove-promtail` | Removes Promtail from older hosts |
| `scripts/setup-ilm.go` | Applies ILM policy to Elasticsearch |
| `scripts/setup-watcher.go` | Watches indices and triggers ILM rollovers |
| `config/Dockerfile.logstash`, `config/filebeat.yml`, `config/ilm-policy.json`, `config/logstash.conf`, `config/logstash.yml` | Pre-rendered reference configs |
| `templates/*.tftpl` | Terraform-rendered equivalents of `config/` (one-to-one mapping) |
| `terraform/checks.tf`, `validation.tf` | Pre/post condition checks |
| `terraform/main.tf`, `providers.tf`, `versions.tf` | Module declarations, provider pinning |
| `terraform/onepassword.tf` | 1Password secret references |
| `terraform/outputs.tf` | Outputs (ELK URLs, credentials path) |
| `terraform/variables.tf` | Input variables |

### 112-mcphub (app + Terraform nested) — Multi-MCP server hub

| File | Purpose |
| --- | --- |
| `Dockerfile.dev-browser`, `Dockerfile.playwright` | Custom MCP image builds |
| `Dockerfile.proxmox` | Proxmox MCP image build |
| `mcp_servers.json` | MCP server registry |
| `validate_mcps.py` | Validates MCP server configuration shape |
| `patches/n8n/license.js`, `patches/n8n/license-state.js` | Runtime patch targets for n8n |
| `op-mcp-server/index.mjs`, `package.json`, `package-lock.json` | Node.js 1Password Connect bridge |
| `config/entrypoint-patch.go` | Container entrypoint patcher |
| `config/filebeat.yml` | Filebeat shipper |
| `config/patch-placeholder.cjs`, `config/patch-sdk-schema.cjs` | Generated SDK patch scaffolding |
| `templates/docker-compose.yml.tftpl`, `templates/docker-compose-op-connect.yml.tftpl` | Container runtimes |
| `templates/filebeat.yml.tftpl` | Filebeat config |
| `templates/mcp_settings.json.tftpl` | Rendered MCP settings JSON |

### 300-cloudflare (Terraform only) — External DNS / Access / Logpush

| File | Purpose |
| --- | --- |
| `access.tf` | Cloudflare Access applications + policies |
| `dns.tf` | DNS records (A, CNAME, TXT, etc.) |
| `identity-provider.tf` | OIDC/SAML IdP wiring |
| `locals.tf` | Shared local values |
| `logpush.tf` | Logpush jobs to ELK / object storage |
| `main.tf` | Module composition and provider config |
| `onepassword.tf` | 1Password secret references (API tokens) |
| `outputs.tf`, `outputs-homelab.tf`, `outputs-jclee.tf`, `outputs-synology.tf` | Split output surfaces by target |
| `checks.tf`, `validation.tf` | Pre/post condition checks |

---

## Numbering Convention / 번호 규칙

| Range / 범위 | Meaning / 의미 | Examples |
| --- | --- | --- |
| `1` – `79` | Reserved | — |
| `80` | Physical host(s) | `80-jclee` |
| `100` – `199` | Proxmox infra (`100-pve` + LXC-based services) | `100-pve`, `101-runner`, `102-traefik`, `103-coredns`, `105-elk`, `107-supabase`, `108-archon`, `110-n8n`, `112-mcphub` |
| `200` – `299` | VM-based app workloads | `200-oc`, `215-synology`, `220-youtube` |
| `300` – `399` | External integrations (not LAN-resident) | `300-cloudflare`, `301-github`, `310-safetywallet`, `320-slack` |
| `400`+ | Cloud platforms | `400-gcp` |

Workspaces with `80`–`255` prefixes map to internal infrastructure. Workspaces with `300+` prefixes are external.

`80`–`255` 접두사는 내부 인프라에 매핑되고, `300+` 접두사는 외부 시스템을 대상으로 합니다.

---

## Workspace Tiers and Apply Order / 워크스페이스 계층과 적용 순서

| Tier / 계층 | Workspaces / 워크스페이스 | Apply order / 적용 순서 |
| --- | --- | --- |
| 0 (core) | `100-pve` | First — provisions all LXC/VM lifecycles and renders configs |
| 1 (infra) | `102-traefik`, `103-coredns`, `105-elk`, `108-archon` | Second (parallel) — consume `remote_state` from `100-pve` |
| 2 (apps) | `110-n8n`, `112-mcphub`, `107-supabase`, `200-oc`, `215-synology`, `220-youtube` | Third — consume `remote_state` from Tier 0/1 |
| Independent / 독립 | `300-cloudflare`, `301-github`, `310-safetywallet`, `320-slack`, `400-gcp` | Any order — no Proxmox dependency |
| Template-only / 템플릿 전용 | `103-coredns`, plus others rendered by `100-pve` | No `.tf` files — rendered as part of `100-pve` apply |

---

## Quick Start / 빠른 시작

### Prerequisites / 사전 요구사항

| Tool / 도구 | Version / 버전 | Purpose / 용도 |
| --- | --- | --- |
| Terraform | `>= 1.7, < 2.0` (pinned to `1.10.5`) | IaC engine |
| `make` | Any modern POSIX make | Wraps all terraform / scripts |
| `go` | `1.22+` | Build operator scripts in `*/scripts/` |
| `python3` | `3.10+` | For `112-mcphub/validate_mcps.py` |
| `node` | `20+` | For `op-mcp-server` |
| `docker` / `docker compose` | `24+` | Local Compose stack for `105-elk` |
| `pre-commit` | `3+` | Optional hooks (`make pre-commit-install`) |
| 1Password CLI (`op`) | `2+` | For secret references in `onepassword.tf` |

### Initialize a workspace / 워크스페이스 초기화

```bash
# Full path
make init SVC=100-pve

# Short alias
make init SVC=pve
make init SVC=traefik
make init SVC=elk
make init SVC=mcphub
make init SVC=cloudflare
```

### Plan a workspace / 워크스페이스 플랜 생성

```bash
make plan SVC=pve
# Opens Terraform plan in CI (never apply locally)
```

> Never run `make apply` locally. CI/CD is the only authorized execution surface.
> 로컬에서 `make apply`를 실행하지 마세요. CI/CD만 유일하게 허가된 실행 경로입니다.

---

## Configuration / 설정

### Secrets / 시크릿

All secrets are stored in the **homelab 1Password vault** and referenced through the shared `modules/shared/onepassword-secrets` module. Each workspace that needs a secret has its own `onepassword.tf`.

모든 시크릿은 **홈랩 1Password 볼트**에 저장되고, 공유 `modules/shared/onepassword-secrets` 모듈을 통해 참조됩니다. 시크릿이 필요한 각 워크스페이스는 자체 `onepassword.tf`를 가집니다.

To rotate a secret / 시크릿 순환:

1. Update the entry in 1Password.
2. Bump or re-plan the relevant workspace; Terraform re-reads on apply.
3. Confirm downstream services picked up the new value via `remote_state` outputs or ELK login events.

### Network / 네트워크

- Homelab domain / 홈랩 도메인: `<HOMELAB_DOMAIN>` (production: `jclee.me`)
- Homelab subnet / 홈랩 서브넷: `<HOMELAB_SUBNET>/24` (production: RFC1918 private range — placeholder here)
- Traefik LXC ID / Traefik LXC ID: `102`
- DNS service discovery / DNS 서비스 디스커버리: `*.lan` via CoreDNS

> The README deliberately avoids hardcoded internal IPs. See `ARCHITECTURE.md` and per-workspace `locals.tf` for the production values.
> 이 README는 의도적으로 내부 IP를 하드코딩하지 않습니다. 프로덕션 값은 `ARCHITECTURE.md`와 워크스페이스별 `locals.tf`를 참조하세요.

### Build Environment / 빌드 환경

`build.env` exports CI-relevant variables (image tags, registry paths, runner labels). Source it before ad-hoc `make` invocations if you override any defaults.

`build.env`는 CI 관련 변수(이미지 태그, 레지스트리 경로, 러너 레이블)를 내보냅니다. 기본값을 재정의할 계획이면 임시 `make` 호출 전에 소싱하세요.

---

## Commands Reference / 명령어 참조

All targets are dispatched through the root `Makefile`. The `SVC` variable selects the workspace.

모든 타깃은 루트 `Makefile`을 통해 디스패치됩니다. `SVC` 변수가 워크스페이스를 선택합니다.

### Terraform / Terraform 명령

| Target / 타깃 | Command / 명령 | Description / 설명 |
| --- | --- | --- |
| `init` | `make init SVC=<ws>` | `terraform init` in the resolved workspace |
| `plan` | `make plan SVC=<ws>` | `terraform plan -out=tfplan` in the resolved workspace |
| `apply` | `make apply SVC=<ws>` | **DISABLED locally** — CI/CD only. Errors out with a deploy-via-CI message |
| `validate` | `make validate SVC=<ws>` | `terraform validate` |
| `fmt` | `make fmt SVC=<ws>` | `terraform fmt -recursive` |
| `verify` | `make verify SVC=<ws>` | `terraform verify` |
| `drift-check` | `make drift-check SVC=<ws>` | Plan-only scan to surface drift |

### Linting and Code Style / 린트와 코드 스타일

| Target / 타깃 | Description / 설명 |
| --- | --- |
| `lint` | Run all linters for the workspace |
| `lint-go` | Run `go vet` / `gofmt` checks against `*/scripts/*.go` |

### Testing / 테스트

| Target / 타깃 | Description / 설명 |
| --- | --- |
| `test` | Run the full test suite |
| `test-unit` | `terraform test` unit tests |
| `test-integration` | Integration tests against ephemeral resources |
| `test-workspace` | Run a per-workspace validation harness |

### Tooling / 도구

| Target / 타깃 | Description / 설명 |
| --- | --- |
| `backup` | Snapshot state for the selected workspace |
| `docs` | Regenerate docs (architecture, ADRs) |
| `pre-commit-install` | Install pre-commit hooks |
| `pre-commit-run` | Run hooks against the full repo |
| `setup` | One-shot bootstrap (tools, hooks, providers) |
| `help` | Print the Makefile help |

### Workspace Resolution / 워크스페이스 해석

| Invocation / 호출 | Meaning / 의미 |
| --- | --- |
| `make plan SVC=100-pve` | Use directory `100-pve/` directly |
| `make plan SVC=pve` | Use alias `ALIAS_pve := 100-pve` → `100-pve/` |
| `make plan SVC=traefik` | Resolves to `102-traefik/terraform/` |
| `make plan SVC=elk` | Resolves to `105-elk/terraform/` |
| `make plan SVC=mcphub` | Resolves to `112-mcphub/` |
| `make plan SVC=cloudflare` | Resolves to `300-cloudflare/` |

Aliases honored / 지원되는 별칭:

```
jclee  pve  runner  traefik  elk  supabase  archon  n8n  mcphub
oc  synology  youtube
cloudflare  github  safetywallet  slack  gcp
```

---

## Local Development / 로컬 개발

### Editing a service template / 서비스 템플릿 수정

1. Locate the workspace / 워크스페이스 찾기:
   ```bash
   ls [0-9]*-*/templates
   ```
2. Edit `templates/*.tftpl` / `templates/*.tftpl` 수정.
3. Run `make plan SVC=<ws>` to render the diff against the deployed state.
4. If the workspace is `100-pve` (and the changed service has an LXC), expect downstream Tier-1 workspaces to also detect drift on the next plan because configs are rendered server-side.

### Validating MCPHub config / MCPHub 설정 검증

```bash
python3 112-mcphub/validate_mcps.py
```

### Building operator Go scripts / 운영자 Go 스크립트 빌드

```bash
cd 105-elk/scripts
go build -o setup-ilm         setup-ilm.go
go build -o setup-watcher     setup-watcher.go
go build -o remove-promtail   remove-promtail.go
```

### Local Compose stack for ELK / ELK 로컬 Compose 스택

```bash
cd 105-elk
docker compose up -d
```

This stack mirrors the rendered configs in `105-elk/config/` and is useful for iterating on log parsing before terraform-rendered equivalents in `templates/` move forward.

이 스택은 `105-elk/config/`의 렌더링된 설정을 미러링하며, Terraform 렌더링 등가물이 진행되기 전에 로그 파싱을 반복 작업할 때 유용합니다.

### IDE & Hooks / IDE 및 훅

- Install hooks / 훅 설치: `make pre-commit-install`
- Run hooks across the repo / 리포 전체 훅 실행: `make pre-commit-run`
- Style conventions / 스타일 규약: [`CODE_STYLE.md`](./CODE_STYLE.md)

---

## Testing / 테스트

| Layer / 계층 | Command / 명령 | Tool / 도구 |
| --- | --- | --- |
| Unit / 단위 | `make test-unit SVC=<ws>` | `terraform test` |
| Integration / 통합 | `make test-integration` | Terraform + Docker harness |
| Workspace validation / 워크스페이스 검증 | `make test-workspace SVC=<ws>` | `terraform validate` + policy checks |
| MCPHub config / MCPHub 설정 | `python3 112-mcphub/validate_mcps.py` | Schema validator |
| ELK pipeline / ELK 파이프라인 | `make -C 105-elk test` (if present) | Go `scripts/setup-*` against ephemeral ES |
| Drift / 드리프트 | `make drift-check SVC=<ws>` | `terraform plan -detailed-exitcode` |

CI runs the full matrix on PRs and on push to `master`. Manual `apply` is gated exclusively by CI.

CI는 PR 및 `master` 푸시에서 전체 매트릭스를 실행합니다. 수동 `apply`는 CI에 의해서만 게이트됩니다.

---

## Contributing / 기여 방법

See [`CONTRIBUTING.md`](./CONTRIBUTING.md) for the full contribution guide (PR process, branch policy, review roles via `OWNERS` / `OWNERS_ALIASES`).

전체 기여 안내(PR 절차, 브랜치 정책, `OWNERS` / `OWNERS_ALIASES`를 통한 리뷰 역할)는 [`CONTRIBUTING.md`](./CONTRIBUTING.md)를 참조하세요.

### Workflow summary / 워크플로 요약

1. Branch off `master`.
2. Edit the relevant `.tf` / `.tftpl` / `Go` / Python files plus their per-workspace `AGENTS.md` if behavior changed.
3. Run `make validate fmt lint test-unit SVC=<ws>` locally.
4. Open a PR — CI will run the matrix; merge requires green CI + OWNERS review.
5. Push to `master` triggers CD; CI applies the change via the authorized deploy job.

---

## Additional Documentation / 추가 문서

| Document | Description |
| --- | --- |
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | Full architecture reference (modules, tiers, request flow) |
| [`DEPENDENCY_MAP.md`](./DEPENDENCY_MAP.md) | Module dependency graph and template inventory |
| [`CODE_STYLE.md`](./CODE_STYLE.md) | Naming, file org, variable, template conventions |
| [`CONTRIBUTING.md`](./CONTRIBUTING.md) | PR process, branch policy, review roles |
| [`103-coredns/AGENTS.md`](./103-coredns/AGENTS.md), [`105-elk/AGENTS.md`](./105-elk/AGENTS.md), [`112-mcphub/AGENTS.md`](./112-mcphub/AGENTS.md), [`300-cloudflare/AGENTS.md`](./300-cloudflare/AGENTS.md) | Per-workspace AI/operator guidance |
| Per-workspace `README.md` (when present) | Workspace-local notes |

---

## License / 라이선스

See [`LICENSE`](./LICENSE) for licensing terms.

라이선스 조건은 [`LICENSE`](./LICENSE)를 참조하세요.