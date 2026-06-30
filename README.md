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

This repository hosts the IaC used to run the homelab and a small set of satellite external integrations (Cloudflare DNS/Access/Logpush, ELK observability, MCPHub tooling, CoreDNS service discovery, and more). There are **no application sources** here — only manifests, Terraform modules, templates, helper Go scripts, and Docker Compose stacks needed to deploy them.

이 저장소는 홈랩과 위성 외부 통합(Cloudflare DNS/Access/Logpush, ELK 관측성, MCPHub 도구, CoreDNS 서비스 디스커버리 등)을 운영하는 데 필요한 IaC를 한곳에 모아둔 곳입니다. 여기에는 **애플리케이션 소스는 없으며**, 배포에 필요한 매니페스트, Terraform 모듈, 템플릿, 보조 Go 스크립트, Docker Compose 스택만 포함됩니다.

Three workspace flavors are supported:

| Flavor / 종류 | Purpose / 용도 | Marker / 표식 |
| --- | --- | --- |
| **Terraform root** | Top-level `*.tf` lives at the workspace root. / 최상위에 `*.tf`가 위치 | Has `main.tf` directly under `NNN-{svc}/` |
| **Terraform under nested dir** | Same as above but isolated under `terraform/`. / 위와 동일, 단 `terraform/` 하위로 격리 | Has `terraform/main.tf` |
| **Template-only** | No Terraform; rendered by the central Proxmox workspace. / Terraform 없음, 중앙 Proxmox 워크스페이스가 렌더링 | Contains only `templates/*.tftpl` |

---

## Features / 주요 기능

| Feature / 기능 | Description / 설명 |
| --- | --- |
| Flat `NNN-SERVICE` naming / 평탄한 번호 명명 | One directory, one identifier. Zero ambiguity for tooling and humans. / 디렉터리 하나, 식별자 하나. 도구와 사람 모두에게 명확합니다. |
| Single top-level `Makefile` / 최상위 Makefile | One entry point for `init`, `plan`, `verify`, `lint`, `fmt`, `backup`, and tests across every workspace. / 모든 워크스페이스의 `init`, `plan`, `verify`, `lint`, `fmt`, `backup`, 테스트를 단일 진입점으로 제어합니다. |
| Workspace aliases / 워크스페이스 별칭 | Run `make plan SVC=elk` instead of `make plan SVC=105-elk/terraform`. / 풀 경로 대신 짧은 별칭으로 호출할 수 있습니다. |
| Terraform 1.7–2.0 compatible / Terraform 1.7–2.0 호환 | Pinned to `>= 1.7, < 2.0` per `versions.tf` files. / 각 워크스페이스의 `versions.tf`에서 버전 범위를 고정합니다. |
| 1Password secret injection / 1Password 비밀 주입 | Secrets fetched at plan/apply time from a vault; never stored in the repo. / 플랜/적용 시점에 볼트에서 비밀을 가져오며, 저장소에는 저장되지 않습니다. |
| Template rendering pipeline / 템플릿 렌더링 파이프라인 | `*.tftpl` files are rendered into host-side `docker-compose.yml`, `Corefile`, `filebeat.yml`, etc., then SSH-deployed. / `*.tftpl` 파일이 호스트용 설정 파일로 렌더링된 뒤 SSH로 배포됩니다. |
| CI/CD-only applies / CI/CD 전용 적용 | Manual `terraform apply` is disabled; every change flows through GitHub Actions. / 수동 `apply`는 비활성화되어 있으며 모든 변경은 GitHub Actions를 통해 흐릅니다. |
| Local backend with committed state / 로컬 백엔드 & 커밋된 상태 | State lives in `.tfstate` files inside the repo; CI concurrency groups serialize applies. / 상태는 저장소 내 `.tfstate`에 보관되며, CI 동시성 그룹이 적용을 직렬화합니다. |
| Go stdlib helper scripts / Go 표준 라이브러리 헬퍼 스크립트 | ILM setup, Promtail removal, entrypoint patching, MCP validation — stdlib-only, easy to audit. / 표준 라이브러리만 사용하는 감사하기 쉬운 헬퍼 스크립트들. |

---

## Architecture / 아키텍처

The homelab is provisioned in tiers. A central Proxmox workspace owns the lifecycle of every LXC and VM; downstream workspaces either consume its remote state or render templates that the orchestrator ships to hosts.

홈랩은 계층(Tier) 단위로 프로비저닝됩니다. 중앙 Proxmox 워크스페이스가 모든 LXC와 VM의 수명 주기를 소유하며, 하위 워크스페이스는 원격 상태를 소비하거나 오케스트레이터가 호스트로 전송할 템플릿을 렌더링합니다.

### Tier overview / 계층 개요

| Tier / 계층 | Role / 역할 | Apply order / 적용 순서 | Example workspaces / 예시 |
| --- | --- | --- | --- |
| 0 — Core / 코어 | LXC/VM lifecycle, IP/role assignment / LXC/VM 수명 주기, IP/역할 할당 | First / 첫 번째 | `100-pve` |
| 1 — Infra / 인프라 | Traefik, ELK, MCPHub, CoreDNS, Supabase, Archon, n8n | Second (after core), parallel / 코어 이후, 병렬 | `102-traefik`, `103-coredns`, `105-elk`, `107-supabase`, `108-archon`, `110-n8n`, `112-mcphub` |
| 2 — Apps / 앱 | Self-hosted app VMs / 자체 호스팅 앱 VM | After infra / 인프라 이후 | `200-oc`, `215-synology`, `220-youtube` |
| 3 — External / 외부 | Cloudflare, GitHub, Slack, Safetywallet, GCP / 외부 API | Any order / 순서 무관 | `300-cloudflare`, `301-github`, `310-safetywallet`, `320-slack`, `400-gcp` |
| 8 — Physical / 물리 | Physical host bootstrap / 물리 호스트 부트스트랩 | First / 첫 번째 | `80-jclee` |
| Template-only / 템플릿 전용 | Rendered by tier 0 / 0계층에서 렌더링 | n/a / 해당 없음 | Workspaces containing only `templates/*.tftpl` |

### Request flow / 요청 흐름

1. Operator edits a workspace (e.g. `300-cloudflare/dns.tf`) and pushes to `master`.
2. GitHub Actions runner (hosted on LXC `101-runner`) detects the change and checks out the repo.
3. Concurrency groups serialize overlapping runs; the runner resolves `SVC` → `TF_DIR` via the alias map.
4. `terraform init` and `terraform plan` run for the changed workspace only.
5. On merge to `master`, the runner executes `terraform apply` using the committed `.tfstate` and 1Password-injected secrets.
6. Proxmox-tier workspaces create/update LXCs and VMs; tier-1 workspaces read `remote_state` and render templates into host configs.
7. Rendered configs are pushed over SSH to `/opt/{service}/` on each host.

1. 운영자가 워크스페이스(예: `300-cloudflare/dns.tf`)를 수정하고 `master`에 푸시합니다.
2. GitHub Actions 러너(LXC `101-runner`)가 변경을 감지하고 저장소를 체크아웃합니다.
3. 동시성 그룹이 겹치는 실행을 직렬화하고, 러너는 별칭 맵을 통해 `SVC` → `TF_DIR`을 해석합니다.
4. 변경된 워크스페이스에 대해서만 `terraform init`과 `terraform plan`을 실행합니다.
5. `master`에 머지되면 러너는 커밋된 `.tfstate`와 1Password 비밀을 사용해 `terraform apply`를 실행합니다.
6. Proxmox 계층 워크스페이스가 LXC/VM을 생성·갱신하고, 1계층 워크스페이스가 `remote_state`를 읽어 호스트 설정으로 템플릿을 렌더링합니다.
7. 렌더링된 설정은 SSH를 통해 각 호스트의 `/opt/{service}/`로 전송됩니다.

### Component map / 구성 요소 맵

| Component / 구성 요소 | Role / 역할 | Notes / 비고 |
| --- | --- | --- |
| `Makefile` | Single command surface / 단일 명령 표면 | Alias map resolves `SVC` → `TF_DIR` |
| Tier 0 Proxmox workspace | Central orchestrator / 중앙 오케스트레이터 | Sole owner of LXC/VM lifecycle |
| Tier 1 infra workspaces | Service deployment & template rendering / 서비스 배포 및 템플릿 렌더링 | Consume `remote_state` from tier 0 |
| 1Password vault `homelab` | Secret store / 비밀 저장소 | Accessed via `onepassword-secrets` module |
| Cloudflare workspace | External DNS / Access / Logpush / 외부 DNS·액세스·로그 푸시 | Independent of Proxmox |
| ELK workspace | Logs and search / 로그 및 검색 | Logstash pipeline, ILM, Filebeat |
| MCPHub workspace | MCP server aggregation / MCP 서버 집계 | Includes patched n8n and Playwright |
| GitHub Actions runner | CI/CD execution / CI/CD 실행 | Hosted on LXC `101-runner` |
| Go helper scripts | Operational tooling / 운영 도구 | stdlib-only, in `scripts/` and per-workspace `scripts/` |

---

## Repository Layout / 저장소 구성

```text
/
├── AGENTS.md                   # Machine-readable project knowledge base
├── ARCHITECTURE.md             # Full architecture reference
├── CODE_STYLE.md               # Naming, file org, variable, template conventions
├── CONTRIBUTING.md             # Contribution workflow
├── DEPENDENCY_MAP.md           # Module dependency graph + template inventory
├── LICENSE                     # Repository license
├── Makefile                    # Single entry point for all workspaces
├── OWNERS                      # Code ownership
├── OWNERS_ALIASES              # Ownership aliases
├── README.md                   # This file
├── build.env                   # Build-time environment variables
├── 103-coredns/                # Tier 1: CoreDNS service discovery (template-only)
│   ├── README.md
│   ├── AGENTS.md
│   └── templates/
│       ├── AGENTS.md
│       ├── Corefile.tftpl
│       ├── docker-compose.yml.tftpl
│       └── filebeat.yml.tftpl
├── 105-elk/                    # Tier 1: ELK stack
│   ├── AGENTS.md
│   ├── docker-compose.yml
│   ├── ilm-policy.json
│   ├── scripts/                # Go stdlib helpers (setup-ilm, setup-watcher, remove-promtail)
│   ├── config/                 # Pre-rendered reference configs
│   ├── templates/              # *.tftpl sources
│   └── terraform/              # Terraform root
│       ├── AGENTS.md
│       ├── README.md
│       ├── checks.tf
│       ├── main.tf
│       ├── onepassword.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── validation.tf
│       ├── variables.tf
│       └── versions.tf
├── 112-mcphub/                 # Tier 1: MCPHub aggregator
│   ├── AGENTS.md
│   ├── README.md
│   ├── Dockerfile.dev-browser
│   ├── Dockerfile.playwright
│   ├── Dockerfile.proxmox
│   ├── mcp_servers.json
│   ├── validate_mcps.py
│   ├── patches/n8n/            # License-state patches for n8n
│   ├── op-mcp-server/          # Node-based 1Password MCP server
│   ├── config/                 # Entrypatch, Filebeat, schema patches
│   └── templates/              # docker-compose, filebeat, mcp_settings templates
└── 300-cloudflare/             # Tier 3: External Cloudflare zone
    ├── AGENTS.md
    ├── README.md
    ├── access.tf
    ├── checks.tf
    ├── dns.tf
    ├── identity-provider.tf
    ├── locals.tf
    ├── logpush.tf
    ├── main.tf
    ├── onepassword.tf
    ├── outputs-homelab.tf
    ├── outputs-jclee.tf
    ├── outputs-synology.tf
    └── outputs.tf
```

---

## Workspaces / 워크스페이스

The following workspaces are present in this repository. Additional workspaces referenced in `AGENTS.md` may live alongside these and follow the same conventions.

이 저장소에 현재 포함된 워크스페이스는 아래와 같습니다. `AGENTS.md`에 언급된 추가 워크스페이스도 동일한 규약을 따릅니다.

| Workspace / 워크스페이스 | Tier / 계층 | Flavor / 종류 | Description / 설명 |
| --- | --- | --- | --- |
| `103-coredns` | 1 / 1계층 | Template-only / 템플릿 전용 | Service discovery via CoreDNS. Rendered by tier 0 from `Corefile.tftpl`, `docker-compose.yml.tftpl`, `filebeat.yml.tftpl`. |
| `105-elk` | 1 / 1계층 | Terraform under `terraform/` | Full ELK stack with Logstash pipeline, ILM policy, Filebeat shipping, and Go helpers (`setup-ilm`, `setup-watcher`, `remove-promtail`). |
| `112-mcphub` | 1 / 1계층 | Template-only + Dockerfiles | MCP server aggregator. Includes patched n8n (`patches/n8n/`), Playwright and Proxmox Dockerfiles, a 1Password-backed MCP server, schema/placeholder patches, and `validate_mcps.py` for config validation. |
| `300-cloudflare` | 3 / 3계층 | Terraform root | External Cloudflare zone: DNS records, Access policies, identity provider, Logpush jobs, and 1Password-backed API tokens. Split outputs for homelab, `jclee.me`, and Synology hosts. |

---

## Numbering Convention / 번호 규칙

Identifiers are flat `NNN-SERVICE` strings. The numeric prefix is semantic, not decorative.

식별자는 `NNN-SERVICE` 형식의 평탄한 문자열입니다. 숫자 접두사는 장식 목적이 아닌 의미를 가집니다.

| Range / 범위 | Meaning / 의미 | Apply order / 적용 순서 |
| --- | --- | --- |
| `1`–`79` | Reserved / 예약 | n/a / 해당 없음 |
| `80`–`99` | Physical hosts / 물리 호스트 | First / 첫 번째 |
| `100`–`199` | Proxmox infrastructure / Proxmox 인프라 | Tier 0 (`100-pve`) first, then tier 1 in parallel |
| `200`–`299` | VM-based apps / VM 기반 앱 | After tier 1 / 1계층 이후 |
| `300`–`399` | External services / 외부 서비스 | Any order, no Proxmox dependency / 순서 무관, Proxmox 의존 없음 |
| `400`+ | Cloud providers / 클라우드 제공자 | Any order / 순서 무관 |

---

## Quick Start / 빠른 시작

This section assumes you already have the runner LXC and 1Password vault configured.

이 섹션은 러너 LXC와 1Password 볼트가 이미 구성되어 있다고 가정합니다.

1. Clone the repository / 저장소를 클론합니다.

   ```bash
   git clone <repo-url> homelab-iac
   cd homelab-iac
   ```

2. Verify available workspaces / 사용 가능한 워크스페이스를 확인합니다.

   ```bash
   make help
   make plan SVC=help  # prints the alias map and target list
   ```

3. Initialize and plan a workspace / 워크스페이스를 초기화하고 플랜을 생성합니다.

   ```bash
   make init  SVC=300-cloudflare
   make plan  SVC=300-cloudflare
   ```

4. Review the plan, commit it if it looks correct, push to `master`, and let CI/CD apply it. Manual `make apply` is intentionally disabled — see [Commands Reference / 명령어 참조](#commands-reference--명령어-참조).
   플랜을 검토하고, 문제가 없으면 커밋 후 `master`에 푸시하여 CI/CD가 적용하도록 합니다. 수동 `make apply`는 의도적으로 비활성화되어 있습니다.

5. For template-only workspaces (e.g. `103-coredns`), there is no Terraform root. Templates are rendered by the tier-0 Proxmox workspace at apply time.
   템플릿 전용 워크스페이스(예: `103-coredns`)에는 Terraform 루트가 없습니다. 템플릿은 적용 시점에 0계층 Proxmox 워크스페이스가 렌더링합니다.

---

## Configuration / 설정

Configuration is layered: workspace-local Terraform variables, 1Password-backed secrets, and per-workspace template variables.

설정은 워크스페이스 로컬 Terraform 변수, 1Password 비밀, 워크스페이스별 템플릿 변수의 세 계층으로 구성됩니다.

### 1Password secrets / 1Password 비밀

Secrets are fetched at plan/apply time from the `homelab` vault. They are injected via the shared `onepassword-secrets` module and accessed as `module.onepassword_secrets.secrets["<key>"]`.

비밀은 플랜/적용 시점에 `homelab` 볼트에서 가져오며, 공유 `onepassword-secrets` 모듈을 통해 주입됩니다. 접근 시 `module.onepassword_secrets.secrets["<key>"]` 형식을 사용합니다.

| Workspace / 워크스페이스 | Secret keys (representative) / 비밀 키 (예시) | Notes / 비고 |
| --- | --- | --- |
| `105-elk` | Elasticsearch admin password, Logstash pipeline credentials / Elasticsearch 관리자 비밀번호, Logstash 파이프라인 자격 증명 | Defined in `terraform/onepassword.tf` |
| `112-mcphub` | 1Password service-account token (used by `op-mcp-server`), upstream API tokens / 1Password 서비스 계정 토큰(`op-mcp-server` 사용), 업스트림 API 토큰 | Wired via `onepassword.tf` |
| `300-cloudflare` | Cloudflare API token, account ID, zone ID / Cloudflare API 토큰, 계정 ID, 존 ID | `onepassword.tf` injects into provider |

### Template variables / 템플릿 변수

`.tftpl` files receive variables from the rendering workspace. Common variable groups:

`.tftpl` 파일은 렌더링 워크스페이스로부터 변수를 전달받습니다. 일반적인 변수 그룹은 다음과 같습니다.

| Group / 그룹 | Source / 출처 | Example usage / 사용 예시 |
| --- | --- | --- |
| `host` / 호스트 | Tier 0 `hosts.tf` | `${host.ip}`, `${host.vmid}`, `${host.role}` |
| `service` / 서비스 | Per-workspace `variables.tf` | `${service.image}`, `${service.version}` |
| `secret` / 비밀 | `onepassword_secrets` module | `${secret.admin_password}` |
| `network` / 네트워크 | Tier 0 `locals.tf` | `${network.subnet}`, `${network.gateway}` |

### Workspace-level files / 워크스페이스 수준 파일

| File / 파일 | Role / 역할 | When edited / 편집 시점 |
| --- | --- | --- |
| `main.tf` | Primary resources / 주 리소스 | Adding/changing managed resources / 관리 리소스 추가·변경 시 |
| `variables.tf` | Input variables / 입력 변수 | Adding new tunable values / 조정 가능한 값 추가 시 |
| `outputs.tf` | Cross-workspace outputs / 워크스페이스 간 출력 | Sharing values with downstream workspaces / 하위 워크스페이스와 공유 시 |
| `checks.tf` | Sentinel/precondition checks / 센티넬·사전 조건 검사 | Adding invariants / 불변식 추가 시 |
| `validation.tf` | Variable validation rules / 변수 검증 규칙 | Tightening input constraints / 입력 제약 강화 시 |
| `versions.tf` | Terraform & provider versions / Terraform·공급자 버전 | Bumping toolchain / 툴체인 업그레이드 시 |
| `providers.tf` | Provider configuration / 공급자 설정 | Adding/rotating provider credentials / 공급자 자격 증명 추가·교체 시 |
| `onepassword.tf` | Secret wiring / 비밀 연결 | Adding/rotating vault items / 볼트 항목 추가·교체 시 |
| `locals.tf` | Local values / 로컬 값 | Internal naming/derivation / 내부 명명·파생 시 |
| `templates/*.tftpl` | Source templates for host-side config / 호스트 설정용 원본 템플릿 | Changing deployed service config / 배포된 서비스 설정 변경 시 |

---

## Commands Reference / 명령어 참조

All commands are dispatched through the top-level `Makefile`. Use `SVC=<alias-or-path>` to select a workspace. Aliases are case-sensitive.

모든 명령은 최상위 `Makefile`을 통해 디스패치됩니다. 워크스페이스를 선택하려면 `SVC=<별칭 또는 경로>`를 사용합니다. 별칭은 대소문자를 구분합니다.

| Command / 명령어 | Aliases / 별칭 | Description / 설명 |
| --- | --- | --- |
| `make help` | — | Print available targets / 사용 가능한 타겟 출력 |
| `make init SVC=<svc>` | `coredns`, `elk`, `mcphub`, `cloudflare`, … | Run `terraform init` in the resolved workspace / 해석된 워크스페이스에서 `terraform init` 실행 |
| `make plan SVC=<svc>` | same as above | Run `terraform plan -out=tfplan` / `terraform plan -out=tfplan` 실행 |
| `make apply SVC=<svc>` | same as above | **Disabled.** Print a CI/CD reminder instead. / **비활성화됨.** CI/CD 안내만 출력 |
| `make verify SVC=<svc>` | same as above | Run `terraform verify` / `terraform verify` 실행 |
| `make validate SVC=<svc>` | same as above | Run `terraform validate` / `terraform validate` 실행 |
| `make lint SVC=<svc>` | same as above | Run `tflint` and friends / `tflint` 등 실행 |
| `make lint-go` | — | Lint Go helper scripts / Go 헬퍼 스크립트 린트 |
| `make fmt SVC=<svc>` | same as above | Run `terraform fmt -recursive` / `terraform fmt -recursive` 실행 |
| `make backup SVC=<svc>` | same as above | Snapshot `.tfstate` and rendered configs / `.tfstate`와 렌더링된 설정 스냅샷 |
| `make drift-check SVC=<svc>` | same as above | Compare live state vs. `.tfstate` / 실제 상태와 `.tfstate` 비교 |
| `make test SVC=<svc>` | same as above | Run all tests for the workspace / 워크스페이스의 모든 테스트 실행 |
| `make test-unit` | — | Run unit tests across the repo / 저장소 전체 단위 테스트 |
| `make test-integration` | — | Run integration tests / 통합 테스트 실행 |
| `make test-workspace SVC=<svc>` | same as above | Run workspace-level Terraform tests / 워크스페이스 수준 Terraform 테스트 |
| `make pre-commit-install` | — | Install pre-commit hooks / pre-commit 훅 설치 |
| `make pre-commit-run` | — | Run pre-commit on all files / 전체 파일에 pre-commit 실행 |
| `make docs` | — | Regenerate documentation / 문서 재생성 |
| `make setup` | — | Bootstrap local tooling / 로컬 도구 부트스트랩 |

### Workspace aliases / 워크스페이스 별칭

The alias map is defined at the top of the `Makefile`. Short names resolve to the appropriate directory; full paths (`NNN-SVC` or `NNN-SVC/terraform`) also work.

별칭 맵은 `Makefile` 상단에 정의되어 있습니다. 짧은 이름은 해당 디렉터리로 해석되며, 풀 경로(`NNN-SVC` 또는 `NNN-SVC/terraform`)도 그대로 사용할 수 있습니다.

| Alias / 별칭 | Resolves to / 해석 경로 |
| --- | --- |
| `coredns` | `103-coredns` (template-only) |
| `elk` | `105-elk/terraform` |
| `mcphub` | `112-mcphub` (template-only) |
| `cloudflare` | `300-cloudflare` |

---

## Local Development / 로컬 개발

### Toolchain / 툴체인

| Tool / 도구 | Version / 버전 | Source / 출처 |
| --- | --- | --- |
| Terraform | `>= 1.7, < 2.0` | `versions.tf` per workspace |
| Go | latest stable / 최신 안정 | Helper scripts use stdlib only / 헬퍼 스크립트는 표준 라이브러리만 사용 |
| Python | 3.x | `validate_mcps.py` |
| Node.js | LTS | `op-mcp-server/` |
| pre-commit | latest / 최신 | `make pre-commit-install` |
| tflint | latest / 최신 | `make lint` |
| terraform-docs | latest / 최신 | `make docs` |

### Local workflow / 로컬 작업 흐름

1. Branch from `master` and edit the relevant workspace.
   `master`에서 브랜치를 만들고 해당 워크스페이스를 수정합니다.

2. Render templates locally (if your workspace has a `config/` directory for reference) and validate.
   템플릿이 있다면 로컬에서 렌더링하고(참조용 `config/` 디렉터리가 있음) 검증합니다.

   ```bash
   make fmt      SVC=105-elk
   make validate SVC=105-elk
   make plan     SVC=105-elk
   ```

3. For MCPHub config changes, run the validator before committing.
   MCPHub 설정 변경 시 커밋 전에 검증기를 실행합니다.

   ```bash
   python 112-mcphub/validate_mcps.py --config 112-mcphub/mcp_servers.json
   ```

4. For Go helpers, run vet and unit tests.
   Go 헬퍼의 경우 vet과 단위 테스트를 실행합니다.

   ```bash
   go vet ./105-elk/scripts/...
   go test ./105-elk/scripts/...
   ```

5. Run pre-commit hooks before pushing.
   푸시 전에 pre-commit 훅을 실행합니다.

   ```bash
   make pre-commit-run
   ```

6. Push and open a PR. CI/CD will run `plan` for changed workspaces. Merging to `master` triggers `apply`.
   푸시 후 PR을 엽니다. CI/CD가 변경된 워크스페이스에 대해 `plan`을 실행하고, `master`로 머지하면 `apply`가 트리거됩니다.

### Network expectations / 네트워크 기대치

| Resource / 리소스 | Expectation / 기대치 |
| --- | --- |
| 1Password API | Outbound HTTPS reachable from the runner / 러너에서 아웃바운드 HTTPS 가능 |
| Cloudflare API | Outbound HTTPS reachable / 아웃바운드 HTTPS 가능 |
| Proxmox API | Reachable on the homelab network from the runner / 홈랩 네트워크에서 러너가 접근 가능 |
| Per-host SSH | Runner can SSH into each managed LXC/VM (key-based auth) / 러너가 키 기반으로 각 LXC/VM에 SSH 가능 |

---

## Testing / 테스트

| Layer / 계층 | Tool / 도구 | Command / 명령어 | Scope / 범위 |
| --- | --- | --- | --- |
| Unit / 단위 | `terraform test` | `make test-unit` | Modules, variable validation, locals |
| Integration / 통합 | `terraform test` + helper scripts | `make test-integration` | Cross-workspace data flow |
| Workspace / 워크스페이스 | `terraform test` | `make test-workspace SVC=<svc>` | End-to-end plan fixtures per workspace |
| Go helpers / Go 헬퍼 | `go test` | `go test ./105-elk/scripts/...` | ILM setup, watcher setup, Promtail removal |
| MCP config / MCP 설정 | `validate_mcps.py` | `python 112-mcphub/validate_mcps.py --config 112-mcphub/mcp_servers.json` | MCP server manifest schema |
| Pre-commit / 사전 커밋 | pre-commit hooks | `make pre-commit-run` | Formatting, linting, secrets |

Testing is intentionally lightweight: the bulk of validation happens at `terraform plan` time, and CI/CD gates merges.

테스트는 의도적으로 가볍게 유지되며, 대부분의 검증은 `terraform plan` 시점에 이루어지고 CI/CD가 머지를 게이트합니다.

---

## Contributing / 기여 방법

1. Read `CODE_STYLE.md` for naming, file organization, variable, and template conventions.
   명명, 파일 구성, 변수 및 템플릿 규약은 `CODE_STYLE.md`를 참고하세요.

2. Read `ARCHITECTURE.md` and `DEPENDENCY_MAP.md` before adding new modules or templates.
   새 모듈이나 템플릿을 추가하기 전에 `ARCHITECTURE.md`와 `DEPENDENCY_MAP.md`를 읽어 주세요.

3. Branch from `master`, keep changes scoped to a single workspace where possible.
   `master`에서 브랜치를 만들고, 가능한 한 단일 워크스페이스 범위로 변경을 유지합니다.

4. Run `make fmt`, `make validate`, and (where applicable) `make plan` locally before pushing.
   푸시 전에 로컬에서 `make fmt`, `make validate`, 가능한 경우 `make plan`을 실행합니다.

5. Run `make pre-commit-run` to catch style/secret issues early.
   스타일/비밀 문제를 사전에 잡기 위해 `make pre-commit-run`을 실행합니다.

6. Open a PR. CI/CD will:
   PR을 엽니다. CI/CD는 다음을 수행합니다.

   - Run `terraform fmt -check`, `terraform validate`, `tflint`.
   - Run `terraform plan` for the changed workspace(s).
   - Comment the plan output on the PR.

7. Approval and merge happen via `OWNERS`/`OWNERS_ALIASES`. Merging to `master` triggers `apply`.
   승인 및 머지는 `OWNERS`/`OWNERS_ALIASES`를 통해 진행되며, `master`로 머지되면 `apply`가 트리거됩니다.

8. See `CONTRIBUTING.md` for the full contribution workflow, including ADRs and runbooks.
   ADR 및 런북을 포함한 전체 기여 절차는 `CONTRIBUTING.md`를 참고하세요.

---

## License / 라이선스

See [`LICENSE`](./LICENSE).

[`LICENSE`](./LICENSE) 파일을 참고하세요.

---

## Additional Documentation / 추가 문서

| Document / 문서 | Purpose / 용도 |
| --- | --- |
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | Full architecture reference, tier diagrams, data flow / 전체 아키텍처 참조, 계층 다이어그램, 데이터 흐름 |
| [`DEPENDENCY_MAP.md`](./DEPENDENCY_MAP.md) | Module dependency graph, template inventory / 모듈 의존성 그래프, 템플릿 인벤토리 |
| [`CODE_STYLE.md`](./CODE_STYLE.md) | Naming, file organization, variables, templates / 명명, 파일 구성, 변수, 템플릿 |
| [`CONTRIBUTING.md`](./CONTRIBUTING.md) | Contribution workflow, ADR process, runbooks / 기여 절차, ADR 프로세스, 런북 |
| [`AGENTS.md`](./AGENTS.md) | Machine-readable project knowledge base / 기계 판독용 프로젝트 지식 베이스 |
| Per-workspace `README.md` | Workspace-specific notes / 워크스페이스별 안내 (예: `105-elk/README.md`, `300-cloudflare/README.md`) |
| Per-workspace `AGENTS.md` | Workspace-specific knowledge / 워크스페이스별 지식 |
| `OWNERS` / `OWNERS_ALIASES` | Code ownership and reviewer aliases / 코드 소유권 및 리뷰어 별칭 |
| `build.env` | Build-time environment variables / 빌드 시 환경 변수 |