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
- [Numbering Convention / 번호 규칙](#numbering--번호-규칙)
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

This repository hosts the IaC used to run a personal homelab and a small set of satellite external integrations (Cloudflare DNS/Access/Logpush, ELK observability, MCPHub tooling, CoreDNS service discovery, etc.). There are **no application sources** here — only manifests, Terraform modules, templates, helper Go scripts, and Docker Compose stacks needed to deploy them.

이 저장소는 개인 홈랩과 위성(衛星) 외부 통합(Cloudflare DNS/Access/Logpush, ELK 관측성, MCPHub 도구, CoreDNS 서비스 디스커버리 등)을 운영하는 데 필요한 IaC를 한곳에 모아둔 곳입니다. 여기에는 **애플리케이션 소스는 없으며**, 배포에 필요한 매니페스트, Terraform 모듈, 템플릿, 보조 Go 스크립트, Docker Compose 스택만 포함됩니다.

Three workspace flavors co-exist / 세 가지 형태의 워크스페이스가 공존합니다:

| Flavor / 형태 | Contents / 내용 | Apply / 적용 방식 |
| --- | --- | --- |
| Terraform workspace | `*.tf` files, providers, state | `terraform plan/apply` (CI/CD only) |
| Template-only workspace | `*.tftpl` files only | Rendered by Tier 0 at apply time |
| Operational helper scripts | Go scripts (stdlib-only) under `scripts/` | Run locally or in CI jobs |

---

## Features / 주요 기능

| Feature / 기능 | Description / 설명 |
| --- | --- |
| **Flat `NNN-SERVICE` naming / 평탄한 명명** | Single-tier numeric prefix; no nested `envs/` per service. |
| **Single `Makefile` control plane / 단일 Makefile 통제** | `make init/plan/verify/lint/test SVC=<alias>` covers every workspace. |
| **Workspace aliases / 워크스페이스 별칭** | Short names (`elk`, `traefik`, `pve`) or full paths — see `ALIAS_*` in the Makefile. |
| **1Password-backed secrets / 1Password 기반 비밀 관리** | Secrets are fetched at plan/apply time via the shared `onepassword-secrets` module. |
| **CI/CD-only apply / CI/CD 전용 적용** | Local `apply` is intentionally disabled to keep state changes auditable. |
| **Template rendering pipeline / 템플릿 렌더링 파이프라인** | `*.tftpl` files are rendered by Tier 0 and SSH-deployed to `/opt/<service>/`. |
| **Stdlib-only Go helpers / 표준 라이브러리 전용 Go 헬퍼** | Operational scripts (ILM setup, watcher setup, promtail removal) use only the Go stdlib. |
| **Bilingual docs / 이중 언어 문서** | Top-level docs are provided in English and Korean. |

---

## Architecture / 아키텍처

The system is organized as numbered workspaces under one repository, with a small set of independent external integrations. A central Tier 0 workspace (`100-pve`) provisions the LXC/VM fleet and renders templates for downstream services.

시스템은 하나의 저장소 안에서 번호가 매겨진 워크스페이스로 구성되며, 소규모의 독립적인 외부 통합을 포함합니다. 중앙 Tier 0 워크스페이스(`100-pve`)가 LXC/VM 플릿을 프로비저닝하고 다운스트림 서비스의 템플릿을 렌더링합니다.

### Workspaces at a Glance / 워크스페이스 한눈에 보기

| Alias / 별칭 | Directory / 디렉터리 | Tier / 계층 | Role / 역할 |
| --- | --- | --- | --- |
| `jclee` | `80-jclee/` | Physical | Workstation / physical host resources |
| `pve` | `100-pve/` | 0 (core) | Central orchestrator; provisions all LXC/VM |
| `runner` | `101-runner/` | 1 (infra) | GitHub Actions self-hosted runner LXC |
| `traefik` | `102-traefik/terraform/` | 1 (infra) | Ingress reverse proxy; routes external traffic |
| `coredns` | `103-coredns/` | Template-only | Service discovery via Corefile rendering |
| `elk` | `105-elk/terraform/` | 1 (infra) | Elasticsearch + Logstash + Kibana stack |
| `supabase` | `107-supabase/` | 1 (infra) | Self-hosted Supabase (database, auth, storage) |
| `archon` | `108-archon/terraform/` | 1 (infra) | Archon coordination/automation service |
| `n8n` | `110-n8n/` | 1 (infra) | Workflow automation (Docker Compose stack) |
| `mcphub` | `112-mcphub/` | 1 (infra) | MCP server hub with patches + connectors |
| `oc` | `200-oc/` | 2 (VM app) | OpenClaw VM workload |
| `synology` | `215-synology/` | 2 (VM app) | Synology VM workload |
| `youtube` | `220-youtube/` | 2 (VM app) | YouTube automation VM workload |
| `cloudflare` | `300-cloudflare/` | 3 (external) | DNS, Access, Identity, Logpush |
| `github` | `301-github/` | 3 (external) | GitHub repo/team configuration |
| `safetywallet` | `310-safetywallet/` | 3 (external) | SafetyWallet product integration |
| `slack` | `320-slack/` | 3 (external) | Slack workspace configuration |
| `gcp` | `400-gcp/` | 3 (external) | Google Cloud Platform resources |

> Note / 참고: Only a subset of directories is present in this checkout. The `Makefile` exposes every alias above; missing directories cause `make init/plan` to print an informative error and list available workspaces.
>
> 위 목록 중 일부분의 디렉터리만 이 체크아웃에 존재합니다. `Makefile`은 위 모든 별칭을 지원하며, 누락된 디렉터리는 `make init/plan` 실행 시 안내 메시지와 사용 가능한 워크스페이스 목록을 출력합니다.

### Tier Definitions / 계층 정의

| Tier / 계층 | Description / 설명 | Apply Order / 적용 순서 |
| --- | --- | --- |
| **0 (core)** | Provisions LXC/VM lifecycles via Proxmox | Apply **first** / 가장 먼저 적용 |
| **1 (infra)** | Depends on Proxmox resources; reads remote state | Apply **second**, in parallel / 그 다음 병렬 적용 |
| **2 (VM app)** | Application VMs that read infra state | Apply **third** / 세 번째 적용 |
| **3 (external)** | No Proxmox dependency | Apply **any time** in parallel / 병렬, 자유 순서 |
| **Template-only** | No `.tf` files; rendered by Tier 0 at apply | N/A — never independently applied |

### Deployment Flow (CI/CD) / 배포 흐름(CI/CD)

Numbered request flow / 번호가 매겨진 요청 흐름:

1. **Push to `master`** / `master` 브랜치에 푸시
2. **GitHub Actions runner LXC (`101-runner`)** picks up the CI job / 러너 LXC가 작업을 받음
3. **Per-workspace job** validates, formats, lints, and runs `terraform plan` / 워크스페이스별 잡이 검증·포맷·린트 후 `terraform plan` 수행
4. **1Password lookup** injects secrets into Terraform via the shared `onepassword-secrets` module / 1Password에서 비밀을 조회해 주입
5. **Plan artifact** is uploaded for review and merged via the configured apply workflow / 플랜 산출물이 업로드 및 리뷰 후 적용
6. **Tier 0 (`100-pve`)** renders `*.tftpl` files into `configs/` and SSH-deploys them to target LXC/VM nodes / Tier 0가 템플릿을 렌더링 후 SSH로 배포
7. **Traefik (`102-traefik`)** picks up new routes; Cloudflare tunnel/DNS propagate external traffic / Traefik이 새 라우트를 수신하고 Cloudflare가 외부 트래픽을 전달

### Config Rendering Pipeline / 설정 렌더링 파이프라인

```
hosts.tf (SSoT) → module.hosts → onepassword_secrets + config_renderer
  → templatefile(.tftpl) → configs/ → SSH deploy to /opt/<service>/
```

`hosts.tf` is the single source of truth for IPs, VMIDs, roles, and ports. The `config_renderer` module materializes every `*.tftpl` into a concrete file that is then shipped to the target node.

`hosts.tf`가 IP, VMID, 역할, 포트의 단일 진실 공급원(SSOT)입니다. `config_renderer` 모듈이 모든 `*.tftpl`을 실재 파일로 구체화한 후 대상 노드에 전송합니다.

---

## Repository Layout / 저장소 구성

The top-level layout reflects the actual contents of this checkout. Each numbered `NNN-SERVICE` directory may contain templates, Terraform code, helper scripts, and per-service documentation.

최상위 구성은 이 체크아웃의 실제 내용을 반영합니다. 번호가 매겨진 각 `NNN-SERVICE` 디렉터리에는 템플릿, Terraform 코드, 헬퍼 스크립트, 워크스페이스별 문서가 포함될 수 있습니다.

```
/
├── AGENTS.md                  # AI/operator knowledge base (project context)
├── ARCHITECTURE.md            # Full architecture reference
├── CODE_STYLE.md              # Naming, file org, variable, template conventions
├── CONTRIBUTING.md            # Contribution guidelines
├── DEPENDENCY_MAP.md          # Module dependency graph + template inventory
├── LICENSE                    # Repository license
├── Makefile                   # Single control plane (init/plan/verify/lint/test/...)
├── OWNERS                     # Code owners
├── OWNERS_ALIASES             # Owner aliases for CODEOWNERS
├── README.md                  # This file
├── build.env                  # Build environment variables
│
├── 103-coredns/               # CoreDNS service discovery templates
│   ├── AGENTS.md
│   ├── README.md
│   └── templates/
│       ├── AGENTS.md
│       ├── Corefile.tftpl
│       ├── docker-compose.yml.tftpl
│       └── filebeat.yml.tftpl
│
├── 105-elk/                   # ELK observability stack
│   ├── AGENTS.md
│   ├── docker-compose.yml
│   ├── ilm-policy.json
│   ├── scripts/               # Go stdlib-only operational scripts
│   │   ├── remove-promtail
│   │   ├── remove-promtail.go
│   │   ├── setup-ilm.go
│   │   └── setup-watcher.go
│   ├── config/                # Reference configs / 빌드 입력
│   │   ├── AGENTS.md
│   │   ├── Dockerfile.logstash
│   │   ├── filebeat.yml
│   │   ├── ilm-policy.json
│   │   ├── logstash.conf
│   │   └── logstash.yml
│   ├── templates/             # Rendered by Tier 0 at apply time
│   │   ├── AGENTS.md
│   │   ├── Dockerfile.logstash.tftpl
│   │   ├── docker-compose.yml.tftpl
│   │   ├── filebeat.yml.tftpl
│   │   ├── ilm-policy.json.tftpl
│   │   ├── logstash.conf.tftpl
│   │   ├── logstash.yml.tftpl
│   │   └── setup-ilm.sh.tftpl
│   └── terraform/             # Tier 1 Terraform workspace
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
│
├── 112-mcphub/                # MCP server hub with n8n patching
│   ├── AGENTS.md
│   ├── Dockerfile.dev-browser
│   ├── Dockerfile.playwright
│   ├── Dockerfile.proxmox
│   ├── README.md
│   ├── mcp_servers.json
│   ├── validate_mcps.py       # Validates MCP server definitions
│   ├── patches/n8n/           # n8n license-state patches
│   │   ├── license-state.js
│   │   └── license.js
│   ├── op-mcp-server/         # 1Password-backed MCP server (Node.js)
│   │   ├── AGENTS.md
│   │   ├── index.mjs
│   │   ├── package-lock.json
│   │   └── package.json
│   ├── config/                # Entrypoint patch utilities
│   │   ├── AGENTS.md
│   │   ├── entrypoint-patch.go
│   │   ├── filebeat.yml
│   │   ├── patch-placeholder.cjs
│   │   └── patch-sdk-schema.cjs
│   └── templates/             # Compose + settings templates
│       ├── AGENTS.md
│       ├── docker-compose-op-connect.yml.tftpl
│       ├── docker-compose.yml.tftpl
│       ├── filebeat.yml.tftpl
│       └── mcp_settings.json.tftpl
│
└── 300-cloudflare/            # Cloudflare DNS/Access/Identity/Logpush
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

> Note / 참고: The `ALIAS_*` map in the Makefile references additional workspaces (`80-jclee`, `100-pve`, `101-runner`, `102-traefik`, `107-supabase`, `108-archon`, `110-n8n`, `200-oc`, `215-synology`, `220-youtube`, `301-github`, `310-safetywallet`, `320-slack`, `400-gcp`) that are defined for alias routing but whose directories are not present in this particular checkout. They will appear once those workspaces are added.
>
> `Makefile`의 `ALIAS_*` 맵은 별칭 라우팅을 위해 정의된 추가 워크스페이스(`80-jclee`, `100-pve`, `101-runner`, `102-traefik`, `107-supabase`, `108-archon`, `110-n8n`, `200-oc`, `215-synology`, `220-youtube`, `301-github`, `310-safetywallet`, `320-slack`, `400-gcp`)를 참조하지만, 이 체크아웃에는 해당 디렉터리가 아직 포함되어 있지 않습니다. 추가되면 자동으로 인식됩니다.

---

## Workspaces / 워크스페이스

### Tier 0 — Core Orchestrator / 핵심 오케스트레이터

| Workspace | Path | Responsibilities / 책임 |
| --- | --- | --- |
| `pve` | `100-pve/` | Provisions all LXC/VM lifecycles; renders every `*.tftpl` and SSH-deploys rendered output. |

### Tier 1 — Infrastructure / 인프라

| Workspace | Path | Responsibilities / 책임 |
| --- | --- | --- |
| `traefik` | `102-traefik/terraform/` | Ingress reverse proxy; consumes `remote_state` from `100-pve`. |
| `coredns` | `103-coredns/` | Service discovery via rendered Corefile. |
| `elk` | `105-elk/terraform/` | Elasticsearch + Logstash + Kibana observability. |
| `supabase` | `107-supabase/` | Self-hosted Supabase stack. |
| `archon` | `108-archon/terraform/` | Archon coordination service. |
| `n8n` | `110-n8n/` | Workflow automation (Docker Compose). |
| `mcphub` | `112-mcphub/` | MCP server hub (1Password-backed `op-mcp-server`, n8n license patches). |
| `runner` | `101-runner/` | Self-hosted GitHub Actions runner LXC. |

### Tier 2 — VM-Based Applications / VM 기반 애플리케이션

| Workspace | Path | Responsibilities / 책임 |
| --- | --- | --- |
| `oc` | `200-oc/` | OpenClaw VM workload. |
| `synology` | `215-synology/` | Synology VM workload. |
| `youtube` | `220-youtube/` | YouTube automation VM workload. |

### Tier 3 — External Integrations / 외부 통합

| Workspace | Path | Responsibilities / 책임 |
| --- | --- | --- |
| `cloudflare` | `300-cloudflare/` | DNS zones, Access applications, Identity provider, Logpush jobs. |
| `github` | `301-github/` | Repository and team configuration. |
| `safetywallet` | `310-safetywallet/` | SafetyWallet product integration. |
| `slack` | `320-slack/` | Slack workspace configuration. |
| `gcp` | `400-gcp/` | Google Cloud Platform resources. |
| `jclee` | `80-jclee/` | Physical workstation host resources. |

### Workspace Inputs and Outputs / 워크스페이스 입출력

| Workspace | Primary Inputs / 입력 | Primary Outputs / 출력 | Side Effects / 부수 효과 |
| --- | --- | --- | --- |
| `100-pve` | Proxmox API, 1Password | VMID allocation, IP allocation | Creates/destroys LXC + VM |
| `102-traefik` | Remote state from `100-pve` | Dynamic config, certificates | Updates reverse-proxy routes |
| `105-elk` | Remote state, ILM policy template | Docker Compose stack, ILM applied | Reads cluster logs |
| `112-mcphub` | 1Password MCP server config | Compose stack, patched n8n image | Exposes MCP servers |
| `300-cloudflare` | Cloudflare API + tokens | DNS records, Access policies, Logpush | Changes public DNS/Access |

---

## Numbering Convention / 번호 규칙

The flat numeric prefix is the single most important convention in this repo. Once it is understood, the entire directory tree is self-documenting.

이 저장소에서 평탄한 숫자 접두사는 가장 중요한 규칙입니다. 한 번 이해하면 전체 디렉터리 트리가 자체 문서화됩니다.

| Range / 범대 | Tier / 계층 | CIDR / 서브넷 | Example / 예시 |
| --- | --- | --- | --- |
| `0–79` | Physical hosts / 물리 호스트 | Physical LAN | `80-jclee` |
| `100–199` | Proxmox infrastructure / Proxmox 인프라 | RFC1918 homelab | `100-pve`, `102-traefik`, `105-elk` |
| `200–299` | VM-based applications / VM 기반 앱 | RFC1918 homelab | `200-oc`, `215-synology`, `220-youtube` |
| `300–399` | External service integrations / 외부 통합 | Public/external | `300-cloudflare`, `301-github`, `320-slack` |
| `400+` | Cloud platforms / 클라우드 플랫폼 | Provider-native | `400-gcp` |

Rules / 규칙:

- Never re-use a number across tiers / 계층 간 번호 재사용 금지.
- Always zero-pad to 3 digits (`105`, not `5`) / 항상 3자리로 0패딩.
- Range boundaries are exclusive at the top: `1–255` = internal, `300+` = external / 상한은 배타적.

---

## Quick Start / 빠른 시작

Most operators should not need to run anything manually. CI/CD handles `plan` and `apply` automatically. Local commands are intended for **validation and testing only**.

대부분의 운영자는 수동으로 아무것도 실행할 필요가 없습니다. CI/CD가 `plan`과 `apply`를 자동으로 처리합니다. 로컬 명령어는 **검증 및 테스트 전용**입니다.

### Prerequisites / 사전 요구 사항

| Tool / 도구 | Version / 버전 | Notes / 참고 |
| --- | --- | --- |
| Terraform | `>= 1.7, < 2.0` (project pins 1.10.5) | `terraform -version` to verify |
| Go | Latest stable | Only required for running `scripts/*.go` |
| Node.js | LTS | Only required for `112-mcphub/op-mcp-server/` |
| 1Password CLI | Latest | Required for any plan that touches `onepassword.tf` |
| Python 3 | 3.x | Required only by `112-mcphub/validate_mcps.py` |
| `make` | GNU Make 4.x | Used to invoke workspace commands |

### First-Time Clone / 최초 클론

1. Clone the repository / 저장소 클론
2. Read `AGENTS.md` for the latest project knowledge base / 최신 프로젝트 지식 베이스 확인
3. Read `ARCHITECTURE.md` for the full architecture reference / 전체 아키텍처 참고
4. Skim `DEPENDENCY_MAP.md` to understand module dependencies between workspaces / 워크스페이스 간 모듈 의존성 확인

### Run Your First Plan / 첫 플랜 실행

Pick a workspace via alias or full path / 별칭 또는 전체 경로로 워크스페이스 선택:

```bash
# Initialize a workspace / 워크스페이스 초기화
make init SVC=elk

# Show what would change / 변경 사항 미리보기
make plan SVC=elk

# Validate the rendered configuration / 렌더링된 설정 검증
make verify SVC=elk
```

Manual apply is intentionally blocked. Push your branch and let CI/CD handle the apply step.

수동 `apply`는 의도적으로 차단되어 있습니다. 브랜치를 푸시하여 CI/CD가 적용하도록 하십시오.

---

## Configuration / 설정

### `build.env`

A top-level file that captures build-time environment variables used by helper scripts and CI runners. Source it before running local scripts:

도우미 스크립트와 CI 러너에서 사용하는 빌드 시점 환경 변수를 보관합니다. 로컬 스크립트 실행 전 반드시 로드:

```bash
set -a; source ./build.env; set +a
```

### 1Password Secrets / 1Password 비밀

All secrets are fetched at plan/apply time. The shared `modules/shared/onepassword-secrets/` module is the only authorized way to read from the homelab vault.

모든 비밀이 플랜/적용 시점에 조회됩니다. 공유 모듈 `modules/shared/onepassword-secrets/`가 홈랩 볼트에서 읽기 위한 유일한 공식 통로입니다.

When you add a new secret:

1. Add the item to the homelab 1Password vault / 홈랩 1Password 볼트에 항목 추가
2. Reference it from the relevant `onepassword.tf` / 해당 `onepassword.tf`에서 참조
3. Pass it through `variables.tf` / `variables.tf`를 통해 전달
4. Document non-obvious names with a comment / 이름이 자명하지 않으면 주석 추가

### Terraform Versions / Terraform 버전

| Component / 구성요소 | Required / 필수 범위 |
| --- | --- |
| Terraform CLI | `>= 1.7, < 2.0` |
| `versions.tf` pins | Per-workspace; aggregate never exceeds CLI bound |

### Workspace Alias Resolution / 워크스페이스 별칭 해석

The `Makefile` follows this resolution order / `Makefile`은 다음 순서로 별칭을 해석합니다:

```text
SVC=elk → look up ALIAS_elk → TF_DIR=105-elk/terraform → cd into it
SVC=105-elk/terraform → ALIAS_$(SVC) is undefined → TF_DIR=SVC as-is
```

If the resolved `TF_DIR` does not exist, the Makefile aborts with a list of direct directories and aliases that do exist.

해석된 `TF_DIR`이 존재하지 않으면, `Makefile`은 직접 디렉터리와 존재하는 별칭 목록을 출력하며 중단합니다.

### Per-Workspace Configuration / 워크스페이스별 설정

Some workspaces expose extra knobs. Always check the workspace's own `README.md` and `AGENTS.md` first.

일부 워크스페이스는 추가 설정을 노출합니다. 항상 해당 워크스페이스의 `README.md`와 `AGENTS.md`를 먼저 확인하십시오.

| Workspace | Notable Config / 주요 설정 |
| --- | --- |
| `105-elk` | ILM policy, Logstash pipeline template, Filebeat inputs |
| `112-mcphub` | MCP server list, n8n license patches, `mcp_settings.json` template |
| `300-cloudflare` | DNS records, Access policies, Identity provider, Logpush jobs |

---

## Commands Reference / 명령어 참조

All commands are phrased as `make <target> [SVC=<alias or path>]`.

모든 명령은 `make <target> [SVC=<별칭 또는 경로>]` 형식입니다.

### Terraform Targets / Terraform 타겟

| Target / 타겟 | Description / 설명 |
| --- | --- |
| `make init SVC=<w>` | Run `terraform init` in the selected workspace. |
| `make plan SVC=<w>` | Produce a `tfplan` file with the proposed changes. |
| `make apply SVC=<w>` | **DISABLED.** Use CI/CD. |

### Validation and Quality Targets / 검증 및 품질 타겟

| Target / 타겟 | Description / 설명 |
| --- | --- |
| `make verify SVC=<w>` | Run `terraform validate` and check rendered outputs. |
| `make fmt` | Run `terraform fmt -recursive` across the repo. |
| `make lint` | Run repository linter. |
| `make lint-go` | Lint the `scripts/**/*.go` helpers. |
| `make validate` | Cross-workspace validation pass. |
| `make drift-check SVC=<w>` | Compare live state against the committed configuration. |
| `make backup SVC=<w>` | Snapshot the workspace's state file. |

### Testing Targets / 테스트 타겟

| Target / 타겟 | Description / 설명 |
| --- | --- |
| `make test` | Run every test target in the order below. |
| `make test-unit` | `terraform test` unit suites. |
| `make test-integration` | Integration suites that exercise module composition. |
| `make test-workspace` | Per-workspace end-to-end tests against a sandbox. |

### Developer Workflow Targets / 개발 워크플로우 타겟

| Target / 타겟 | Description / 설명 |
| --- | --- |
| `make pre-commit-install` | Install pre-commit hooks (if used). |
| `make pre-commit-run` | Run the pre-commit hook set against the working tree. |
| `make docs` | Regenerate API references and embedded diagrams. |
| `make setup` | Bootstrap local tooling (`tfenv`, `tflint`, etc.). |
| `make help` | Print the auto-generated target help. |

### Common Recipes / 자주 쓰는 조합

```bash
# Iterating on a single workspace / 단일 워크스페이스 반복 작업
make init SVC=elk && make plan SVC=elk

# Format everything before a PR / PR 전 전체 포맷
make fmt

# Lint Go scripts only / Go 스크립트만 린트
make lint-go

# Full pre-PR sweep / PR 전 전체 점검
make fmt && make lint && make test
```

---

## Local Development / 로컬 개발

### Working on a Single Workspace / 단일 워크스페이스 작업

1. Pick the workspace and locate its `AGENTS.md` / 워크스페이스를 선택하고 `AGENTS.md` 위치 확인
2. Read the workspace's own `README.md` (if present) for service-specific notes / 서비스별 메모는 워크스페이스의 `README.md` 참고
3. Edit either the Terraform code or templates / Terraform 코드나 템플릿 편집
4. Run `make init` once, then `make plan` to preview / 최초 1회 `make init` 후 `make plan`으로 미리보기
5. Run `make verify` and the appropriate test target / `make verify`와 적절한 테스트 타겟 실행

### Template-Only Workspaces / 템플릿 전용 워크스페이스

Template-only workspaces (e.g. `103-coredns`, `110-n8n`, `112-mcphub`) carry no Terraform code of their own. Their `*.tftpl` files are rendered by Tier 0 at apply time. To preview locally:

템플릿 전용 워크스페이스(예: `103-coredns`, `110-n8n`, `112-mcphub`) 자체는 Terraform 코드를 갖지 않습니다. 해당 `*.tftpl` 파일은 적용 시점에 Tier 0에 의해 렌더링됩니다. 로컬에서 미리 보려면:

1. Run `make plan SVC=pve` to render the template outputs / `make plan SVC=pve`로 템플릿 출력 렌더링
2. Inspect the generated file under `100-pve/configs/` / `100-pve/configs/` 아래 생성된 파일 확인
3. Iterate on the `.tftpl` source until outputs match expectations / 출력이 기대와 일치할 때까지 `.tftpl` 원본 반복 편집

### Editing Helper Scripts / 헬퍼 스크립트 편집

Helper scripts in `105-elk/scripts/*.go` and similar locations use **only the Go standard library**:

`105-elk/scripts/*.go` 등 위치의 헬퍼 스크립트는 **Go 표준 라이브러리만** 사용합니다:

- No `go.mod` / `go.sum` is required / `go.mod` / `go.sum` 불필요
- Run any of them with `go run path/to/script.go args…`
- Keep error messages actionable and bilingual-friendly / 오류 메시지는 실행 가능하고 명확하게 유지

### Validating MCP Server Definitions / MCP 서버 정의 검증

```bash
python3 112-mcphub/validate_mcps.py 112-mcphub/mcp_servers.json
```

The validator checks structural correctness of the MCP server registry. Run this whenever `mcp_servers.json` changes.

이 검증기는 MCP 서버 레지스트리의 구조적 정확성을 확인합니다. `mcp_servers.json`을 변경할 때마다 실행하십시오.

### Environment Variables for Local Runs / 로컬 실행용 환경 변수

The `build.env` file is the source of truth for build-time variables. Always source it before invoking helpers:

`build.env` 파일이 빌드 시점 변수의 진실 공급원입니다. 헬퍼 호출 전 항상 로드:

```bash
set -a; source ./build.env; set +a
```

---

## Testing / 테스트

Three layers of testing are available; pick the one closest to the change you are making.

세 가지 테스트 계층이 제공되며, 변경 사항에 가장 가까운 계층을 선택합니다.

| Layer / 계층 | Command / 명령 | Scope / 범위 | When to Run / 실행 시점 |
| --- | --- | --- | --- |
| Unit | `make test-unit SVC=<w>` | A single module's inputs/outputs | Every commit affecting modules |
| Integration | `make test-integration SVC=<w>` | Module composition | Before opening a PR |
| Workspace | `make test-workspace SVC=<w>` | Full workspace end-to-end against sandbox | Pre-merge, after major refactors |
| Full sweep | `make test` | All three layers in order | Before release tagging |

### Script-Level Tests / 스크립트 수준 테스트

For the Go helpers under `scripts/` and per-workspace `scripts/` directories, prefer running them with realistic inputs in a sandbox LXC. They are stdlib-only and quick to execute end-to-end.

`s scripts/ ` 및 워크스페이스별 `scripts/` 디렉터리의 Go 헬퍼는 샌드박스 LXC에서 현실적인 입력으로 실행하는 것을 권장합니다. 표준 라이브러리만 사용하여 빠르게 종단 간 실행됩니다.

### Validation Hooks / 검증 훅

Two on-disk validate helpers exist:

- `validate_mcps.py` — structural validation of `mcp_servers.json`
- `setup-ilm.go` / `setup-watcher.go` / `remove-promtail.go` — idempotent operational setup; safe to re-run

두 개의 디스크 기반 검증 헬퍼:

- `validate_mcps.py` — `mcp_servers.json`의 구조적 검증
- `setup-ilm.go` / `setup-watcher.go` / `remove-promtail.go` — 멱등성을 갖는 운영 셋업; 재실행 안전

---

## Contributing / 기여 방법

1. Read `CONTRIBUTING.md` for the canonical contribution flow / 표준 기여 절차는 `CONTRIBUTING.md` 참고
2. Read `CODE_STYLE.md` for naming, file organization, variable, and template conventions / 명명·파일 구성·변수·템플릿 규칙은 `CODE_STYLE.md` 참고
3. Read `DEPENDENCY_MAP.md` to understand how your change propagates between workspaces / 워크스페이스 간 변경 전파는 `DEPENDENCY_MAP.md` 참고
4. Pick the tier / 계층 선택:
   - Tier 0 / 핵심: changes to `100-pve` require explicit maintainer review / 명시적 메인테이너 리뷰 필요
   - Tier 1 / 인프라: ensure remote-state inputs from `100-pve` are honored / `100-pve`의 원격 상태 입력 존중
   - Tier 2–3 / 외부: less coupling, but always keep template + state coverage / 결합도는 낮지만 템플릿 + 상태 커버리지를 유지
5. Branch off `master`, run `make fmt lint test`, and open a PR / `master`에서 분기, `make fmt lint test` 실행 후 PR 열기
6. Code owners are defined in `OWNERS` and `OWNERS_ALIASES`; review routing is automatic / 코드 오너는 `OWNERS` 및 `OWNERS_ALIASES`에 정의되어 자동 라우팅

### Pull Request Checklist / PR 체크리스트

| Item / 항목 | Required? |
| --- | --- |
| `make fmt` passes | ✓ |
| `make lint` passes | ✓ |
| `make verify SVC=<w>` passes | ✓ |
| `make test-unit` / `test-integration` pass (when applicable) | ✓ |
| Updated the workspace's `README.md` / `AGENTS.md` if behavior changed | ✓ |
| Re-rendered templates for template-only workspaces | ✓ |

---

## Additional Documentation / 추가 문서

| File | Purpose / 용도 |
| --- | --- |
| `AGENTS.md` | AI/operator knowledge base; auto-updated context for project navigation. |
| `ARCHITECTURE.md` | Long-form architecture reference; complements this README. |
| `CODE_STYLE.md` | Authoritative style guide: naming, file organization, variables, templates. |
| `CONTRIBUTING.md` | Canonical contribution workflow. |
| `DEPENDENCY_MAP.md` | Module dependency graph and template inventory. |
| `OWNERS` / `OWNERS_ALIASES` | Code-owner routing for reviews. |
| Per-workspace `AGENTS.md` | Service-specific context: how that workspace is wired up. |
| Per-workspace `README.md` | Service-specific notes, knobs, and operator guidance. |

Detailed Mermaid diagrams, sequence flows, and per-service runbooks intentionally live in dedicated documentation files rather than this README, so this landing page stays scannable.

세부 Mermaid 다이어그램, 시퀀스 흐름, 서비스별 런북은 의도적으로 본 README 대신 전용 문서 파일에 위치합니다. 본 랜딩 페이지는 빠르게 훑어볼 수 있도록 유지됩니다.

---

## License / 라이선스

See the [`LICENSE`](./LICENSE) file at the root of this repository for license terms and conditions.

라이선스 조건은 저장소 루트의 [`LICENSE`](./LICENSE) 파일을 참고하십시오.