# jclee.me 홈랩 Terraform 인프라 / Terraform Homelab Infrastructure

[![Terraform](https://img.shields.io/badge/Terraform-1.10.5-7B42BC?logo=terraform&logoColor=white)](.)
[![Makefile](https://img.shields.io/badge/Build-Makefile-0277BD?logo=gnu&logoColor=white)](Makefile)
[![Secrets](https://img.shields.io/badge/Secrets-1Password-1572B6)](.)
[![CI](https://img.shields.io/badge/CI-GitHub_Actions-2088FF?logo=github-actions&logoColor=white)](.github/workflows/)
[![Status](https://img.shields.io/badge/Status-Active-brightgreen)](.)
[![License](https://img.shields.io/badge/License-See%20LICENSE-blue)](LICENSE)

## 개요 / Overview

**한국어.** `jclee.me` 홈랩을 코드로 정의·유지하기 위한 Terraform 저장소입니다. Proxmox 위의 LXC/VM 플릿, 내부 서비스(Traefik, CoreDNS, ELK, MCP Hub, Synology, YouTube, Open Cloud 등), 그리고 Cloudflare·GCP 같은 외부 서비스를 **번호가 매겨진 워크스페이스** 단위로 프로비저닝합니다. 모든 비밀은 1Password 볼트 `homelab`에서 주입하고, 상태는 워크스페이스 옆 로컬에 두며, GitHub Actions의 동시성 그룹으로 apply 순서를 직렬화합니다. 일부 워크스페이스(`103-coredns`, `112-mcphub` 등)는 템플릿 전용이며, `100-pve`가 `.tftpl` 파일을 렌더링해 서비스 컨피그를 중앙에서 생성합니다.

**English.** A Terraform repository that defines and maintains the `jclee.me` homelab as code. It provisions a Proxmox LXC/VM fleet, internal services (Traefik, CoreDNS, ELK, MCP Hub, Synology, YouTube, Open Cloud, etc.), and external providers (Cloudflare, GCP) through numbered workspaces. Secrets are injected from the 1Password `homelab` vault, state is stored locally beside each workspace, and GitHub Actions concurrency groups serialize applies. A few workspaces are template-only — `100-pve` renders their `.tftpl` configs centrally.

## 한눈에 보기 / At a Glance

| 항목 / Item | 값 / Value |
|---|---|
| 도메인 / Domain | `jclee.me` |
| 사설 LAN / Private LAN | RFC1918 홈랩 서브넷 (`<homelab-subnet>` 자리표시자 사용) |
| Terraform | 1.10.5 (제약: `>= 1.7, < 2.0`) |
| 워크스페이스 / Workspaces | 13개의 번호 디렉터리, 12개의 Makefile 별칭 |
| 진입 모듈 / Module entry points | `modules/{proxmox,shared,cloudflare,elasticstack}` |
| 비밀 저장소 / Secrets | 1Password vault `homelab` (`modules/shared/onepassword-secrets/`) |
| CI/CD | GitHub Actions, 동시성 그룹 기반 직렬화 |
| 상태 백엔드 / State backend | 로컬 (워크스페이스 옆 디스크) |

## 목적 / Purpose

**한국어.** 이 저장소는 홈랩 인프라를 **재현 가능**, **감사 가능**, **비밀 안전**하게 유지하는 것을 목표로 합니다. 호스트 추가, 라우트 변경, 로깅 파이프라인 수정, 외부 엣지(Cloudflare) 변경 등 모든 작업을 코드로 처리해 수동 개입과 비밀 노출을 줄입니다. 단일 출처(SSoT) 원칙으로 호스트·IP·VMID는 `100-pve/envs/prod/hosts.tf`에서, 비밀은 1Password에서, 템플릿은 `templates/*.tftpl`에서만 관리합니다.

**English.** The goal of this repository is to keep the homelab **reproducible**, **auditable**, and **secret-safe**. Host changes, route updates, logging pipeline edits, and external edge (Cloudflare) changes all flow through code, minimizing manual steps and secret leaks. Single sources of truth: hosts/IPs/VMIDs in `100-pve/envs/prod/hosts.tf`, secrets in 1Password, templates in `templates/*.tftpl`.

### 주요 사용 사례 / Primary Use Cases

- 새 LXC/VM 추가 또는 리사이즈 (호스트/IP SSoT 기반)
- Traefik 라우트, CoreDNS 분할 DNS, ELK 파이프라인/ILM 갱신
- Cloudflare DNS, 터널, Workers 배포
- MCP Hub 및 1Password Connect 자산 동기화
- 1Password 비밀 회전 후 Terraform 재적용

## 패키지 구성 / Package Contents

저장소 최상위에는 공통 문서(`AGENTS.md`, `ARCHITECTURE.md`, `CODE_STYLE.md`, `CONTRIBUTING.md`, `DEPENDENCY_MAP.md`), 운영 메타데이터(`OWNERS`, `OWNERS_ALIASES`, `LICENSE`, `Makefile`, `build.env`), 그리고 다음 번호 워크스페이스가 있습니다. 이 트리는 저장소의 실제 최상위 레이아웃을 반영합니다.

```text
.
├── AGENTS.md
├── ARCHITECTURE.md
├── CODE_STYLE.md
├── CONTRIBUTING.md
├── DEPENDENCY_MAP.md
├── LICENSE
├── Makefile
├── OWNERS
├── OWNERS_ALIASES
├── README.md
├── build.env
├── 103-coredns/                  # Template-only split-DNS 워크스페이스
│   ├── AGENTS.md
│   ├── README.md
│   └── templates/                # Corefile, docker-compose, filebeat 템플릿
├── 105-elk/                      # ELK 스택 Terraform + 템플릿 + 보조 스크립트
│   ├── AGENTS.md
│   ├── docker-compose.yml
│   ├── ilm-policy.json
│   ├── scripts/                  # setup-ilm / setup-watcher / remove-promtail (Go)
│   ├── config/                   # 렌더링된 산출물 (Dockerfile, filebeat, logstash)
│   ├── templates/                # *.tftpl
│   └── terraform/                # checks, main, onepassword, outputs, providers,
│                                 # validation, variables, versions
├── 112-mcphub/                   # Template-only MCP Hub + 1Password Connect 자산
│   ├── AGENTS.md
│   ├── Dockerfile.dev-browser
│   ├── Dockerfile.playwright
│   ├── Dockerfile.proxmox
│   ├── README.md
│   ├── mcp_servers.json
│   ├── validate_mcps.py
│   ├── op-mcp-server/            # 1Password Connect MCP 서버
│   ├── config/                   # entrypoint 패치, filebeat, SDK 스키마 패치
│   └── templates/                # docker-compose, filebeat, mcp_settings 템플릿
└── 300-cloudflare/               # 외부 Cloudflare Terraform + 스크립트 + Workers
    ├── AGENTS.md
    ├── README.md
    ├── inventory/secrets.yaml
    ├── scripts/                  # audit, collect, deploy-worker, generate-bindings, sync
    ├── docs/requirements.md
    └── workers/
        ├── AGENTS.md
        └── synology-proxy/       # Synology 프록시 Worker
```

다른 번호 워크스페이스(`80-jclee`, `100-pve`, `101-runner`, `102-traefik`, `200-oc`, `215-synology`, `220-youtube`, `310-safetywallet`, `400-gcp`)는 같은 번호 체계에 속하며 `Makefile`의 별칭으로 제어됩니다. 자세한 분포는 [AGENTS.md](AGENTS.md)의 STRUCTURE 섹션을 참조하세요.

## 상태 / Status

| 영역 / Area | 상태 / Status | 비고 / Notes |
|---|---|---|
| 코드 / Code | Active | 일상적으로 진화 중 |
| CI/CD | Active | GitHub Actions |
| 상태 / State | 로컬 | 동시성 그룹으로 직렬화 |
| 비밀 / Secrets | 1Password | `homelab` 볼트에서만 주입 |
| 프로덕션 준비 / Production-ready | 부분 / Partial | 홈랩 사용 목적의 환경 |
| 1Password Access | 없음 / Removed | Cloudflare 모듈 등에서 의도적으로 제거됨 |

## 먼저 읽을 파일 / First Files to Read

1. **이 문서** — 저장소 진입점과 운영 표면
2. **[Makefile](Makefile)** — 모든 명령의 단일 진입 계약
3. **[AGENTS.md](AGENTS.md)** — 프로젝트 지식 베이스, 코드 맵, 안티패턴
4. **[ARCHITECTURE.md](ARCHITECTURE.md)** — 시스템 토폴로지
5. **[CODE_STYLE.md](CODE_STYLE.md)** · **[CONTRIBUTING.md](CONTRIBUTING.md)** · **[DEPENDENCY_MAP.md](DEPENDENCY_MAP.md)** — 운영 규약
6. `100-pve/terraform/` + `100-pve/envs/prod/hosts.tf` — 호스트/IP/VMID SSoT
7. **`modules/shared/onepassword-secrets/`** — 비밀 검색 패턴
8. **`.github/workflows/`** — CI/CD 파이프라인

## 진입점 / API or Entry Points

| 영역 / Area | 진입점 / Entry point |
|---|---|
| 코어 플릿 / Core fleet | `100-pve/terraform/main.tf` |
| Tier 1 앱 / Tier 1 apps | `102-traefik/terraform/main.tf`, `105-elk/terraform/main.tf` |
| 외부 프로바이더 / External | `215-synology/main.tf`, `300-cloudflare/terraform/main.tf` |
| 모듈 / Modules | `modules/proxmox/*/main.tf`, `modules/cloudflare/tunnel/main.tf`, `modules/elasticstack/*/main.tf` |
| 템플릿 / Templates | `{NNN}-{svc}/templates/*.tftpl` (100-pve가 렌더링) |
| 도구 / Tooling | `scripts/validate-docs/main.go`, `scripts/audit-workflows.go`, `300-cloudflare/scripts/collect.go` |
| Workers | `300-cloudflare/workers/*/src/index.ts` |
| MCP 서버 매니페스트 | `112-mcphub/mcp_servers.json` |
| ELK 인덱스 정책 | `105-elk/ilm-policy.json` |

## 빠른 시작 / Quickstart

### 사전 준비 / Prerequisites

- Terraform 1.10.5 (`>= 1.7, < 2.0`)
- Go (Make 타겟 중 Go 기반 유틸리티 사용)
- 1Password CLI + `homelab` 볼트 접근 권한
- Proxmox API 토큰, Cloudflare API 토큰 등 (자세한 내용 [`modules/shared/onepassword-secrets/`](modules/shared/onepassword-secrets/))

### 일반 워크플로우 / Typical Workflow

```bash
# 1) 워크스페이스 초기화 (예: Proxmox Tier 0)
make init SVC=pve

# 2) 변경 계획 검토 (tfpla로 저장)
make plan SVC=pve

# 3) 적용
make apply SVC=pve

# 4) 검증
make verify SVC=pve
```

### 사용 가능한 별칭 / Available Aliases

`SVC`는 풀 경로(`100-pve`) 또는 짧은 별칭(`pve`)을 받습니다. 별칭이 정의되어 있으면 자동으로 `{workspace}/terraform/`으로 해석됩니다.

| 별칭 / Alias | 디렉터리 / Directory |
|---|---|
| `jclee` | `80-jclee` |
| `pve` | `100-pve/terraform` |
| `runner` | `101-runner` |
| `traefik` | `102-traefik/terraform` |
| `elk` | `105-elk/terraform` |
| `mcphub` | `112-mcphub` |
| `oc` | `200-oc` |
| `synology` | `215-synology` |
| `youtube` | `220-youtube` |
| `cloudflare` | `300-cloudflare/terraform` |
| `safetywallet` | `310-safetywallet` |
| `gcp` | `400-gcp` |

기본값은 `SVC=100-pve`이며, 정의되지 않은 값을 넘기면 Makefile이 사용 가능한 디렉터리를 안내합니다.

## 아키텍처 / Architecture

### 번호 체계 / Numbering Scheme

| 계층 / Tier | 번호 범위 / Range | 성격 / Character | 예시 / Examples |
|---|---|---|---|
| 보조 / Auxiliary | 80- | 개인 워크스테이션 스켈레톤 | `80-jclee` |
| Tier 0 (코어) | 100- | Proxmox 오케스트레이터, 호스트 SSoT | `100-pve` |
| Tier 1 (앱) | 101-199 | 내부 서비스 (프록시, DNS, 로깅, MCP) | `101-runner`, `102-traefik`, `103-coredns`, `105-elk`, `112-mcphub` |
| Tier 2 (워크로드) | 200-299 | 사용자 워크로드 | `200-oc`, `215-synology`, `220-youtube` |
| Tier 3 (외부) | 300-499 | 외부/엣지 서비스 | `300-cloudflare`, `310-safetywallet`, `400-gcp` |

1-255번대는 내부 인프라(사설 LAN) 가정, 300번 이상은 외부(Cloudflare, GCP 등) 가정입니다.

### 컴포넌트 역할 / Component Roles

| 컴포넌트 / Component | 책임 / Responsibility |
|---|---|
| `100-pve` | Proxmox 플릿 SSoT, `.tftpl` 중앙 렌더러 |
| `102-traefik` | 내부 리버스 프록시 라우트, 백엔드 IP는 호스트 맵에서만 |
| `103-coredns` | 사설 DNS (분할 DNS) 템플릿 |
| `105-elk` | ELK 스택, ILM 정책, 보조 Go 스크립트 |
| `112-mcphub` | MCP Hub + 1Password Connect 자산 템플릿 |
| `300-cloudflare` | DNS, 터널, Workers, 비밀 인벤토리, 동기화 스크립트 |
| `modules/*` | 재사용 모듈 (proxmox, shared, cloudflare, elasticstack) |

### 평면 요청 흐름 / Flat Request Flow

1. **오퍼레이터**가 `make plan SVC=<alias>` 또는 GitHub PR로 변경을 제출합니다.
2. **GitHub Actions**가 동시성 그룹으로 워크플로우 실행을 직렬화합니다.
3. **Terraform**이 `100-pve` 또는 해당 워크스페이스의 `.tf`를 평가합니다.
4. **`100-pve`**가 필요 시 `{NNN}-{svc}/templates/*.tftpl`을 렌더링해 서비스 컨피그를 생성합니다.
5. **Proxmox / Cloudflare / GCP** 등 프로바이더에 변경을 적용합니다.
6. **`modules/shared/onepassword-secrets/`**가 1Password에서 비밀을 환경 변수로 주입합니다.
7. **로컬 상태**가 워크스페이스 옆에 기록됩니다. (`100-pve/terraform`, `105-elk`는 plan/state 산출물 유지의 명시적 예외)

## 설정 / Configuration

| 영역 / Area | 위치 / Location | 비고 / Notes |
|---|---|---|
| 호스트/IP/VMID SSoT | `100-pve/envs/prod/hosts.tf` | 변경의 단일 출처 |
| 변수 / Variables | `{workspace}/terraform/variables.tf` | 명시적 타입, 설명 필수 |
| 비밀 / Secrets | 1Password `homelab` 볼트 | `modules/shared/onepassword-secrets/` |
| 빌드 환경 / Build env | `build.env` | 빌드 시 사용 |
| ELK ILM 정책 | `105-elk/ilm-policy.json` | 인덱스 수명 주기 |
| Logstash 파이프라인 | `105-elk/config/logstash.conf` | 파싱/인덱싱 정의 |
| MCP 서버 매니페스트 | `112-mcphub/mcp_servers.json` | MCP 서버 매니페스트 |
| Cloudflare 비밀 인벤토리 | `300-cloudflare/inventory/secrets.yaml` | 스크립트가 읽음 |
| 프로바이더 버전 제약 | `{workspace}/terraform/versions.tf` | 모듈/저장소 단위 |

## 명령어 참조 / Commands Reference

| 명령 / Command | 설명 / Description |
|---|---|
| `make init SVC=<alias>` | Terraform 초기화 |
| `make plan SVC=<alias>` | Plan 생성 (`tfpla`로 저장) |
| `make apply SVC=<alias>` | Plan 적용 |
| `make verify SVC=<alias>` | 적용 후 검증 |
| `make validate` | 모든 `*.tf` 검증 (워크스페이스 자동 스캔) |
| `make fmt` | 모든 `*.tf` 포맷 |
| `make lint` / `make lint-go` | 정적 분석 (Terraform / Go) |
| `make test` | 전체 테스트 |
| `make test-unit` | 단위 테스트 |
| `make test-integration` | 통합 테스트 |
| `make test-workspace` | 워크스페이스 단위 |
| `make drift-check` | 실제 상태와 코드 차이 검사 |
| `make backup` | 백업 |
| `make pre-commit-install` / `make pre-commit-run` | 사전 커밋 훅 |
| `make docs` | 문서 생성 |
| `make setup` | 초기 환경 준비 |
| `make help` | 사용 가능한 타겟 목록 |

기본 `SVC`는 `100-pve`입니다. `*.tf` 검색은 `.terraform/`, `tests/`, `modules/` 캐시/외부 경로를 자동으로 제외합니다.

## 로컬 개발 / Local Development

- 식별자 규약: `snake_case` (Terraform), `kebab-case` (템플릿·스크립트)
- 단일 인스턴스 리소스는 `resource "x" "this"` 컨벤션을 따릅니다.
- 변수에는 **명시적 타입**과 **설명**을 반드시 부여하고, 출력에도 설명을 붙입니다.
- 템플릿은 `templates/*.tftpl`에만 두고, 렌더된 출력(`config/`, `docker-compose.yml` 등)은 절대 직접 편집하지 않습니다 — 항상 템플릿과 `100-pve` 렌더러를 통해 갱신합니다.
- 앱 로직은 인라인 cloud-init에 두지 않고 템플릿으로 분리합니다.
- 활성 Terraform 워크스페이스는 `{workspace}/terraform/` 레이아웃을 따르며, `215-synology/`만 평면 레이아웃의 예외입니다.
- PR 전 `make validate fmt lint pre-commit-run`을 실행합니다.
- 워크플로우 변경은 [`.github/AGENTS.md`](.github/AGENTS.md) 정책과 부합해야 합니다.

## 테스트 / Testing

| 타겟 / Target | 범위 / Scope |
|---|---|
| `make test` | 전체 |
| `make test-unit` | 단위 테스트 |
| `make test-integration` | 통합 테스트 |
| `make test-workspace` | 워크스페이스 단위 |
| `make drift-check` | 실제 상태와 코드 차이 검사 |

자세한 동작은 [`tests/AGENTS.md`](tests/AGENTS.md)를 참조하세요. 기본적으로 프로바이더는 모킹되며, 실제 프로바이더 호출은 의도적으로 분리된 통합 경로에서 다룹니다.

## 기여 / Contributing

- 절차는 [CONTRIBUTING.md](CONTRIBUTING.md), 스타일은 [CODE_STYLE.md](CODE_STYLE.md)를 따릅니다.
- PR에는 영향받는 워크스페이스의 `make plan` 결과를 첨부합니다.
- 새 비밀은 **절대 저장소에 커밋하지 않고** 1Password `homelab` 볼트에만 둡니다.
- 아키텍처 결정(ADR)은 [`docs/`](docs/)에 추가 전용(append-only)으로 기록합니다.
- 워크플로우·CI 변경은 [`.github/AGENTS.md`](.github/AGENTS.md)와 [`.github/workflows/`](.github/workflows/)의 기존 패턴을 따릅니다.
- Cloudflare 영역 변경 시 [`300-cloudflare/docs/requirements.md`](300-cloudflare/docs/requirements.md) 요구사항을 함께 검토합니다.

## 운영자 / Maintainers

- 코드 오너십과 별칭은 [OWNERS](OWNERS) 및 [OWNERS_ALIASES](OWNERS_ALIASES)를 참조합니다.
- 일반 운영 문의는 저장소 이슈 트래커를 사용하고, 보안 관련 민감 사안은 `OWNERS`에 명시된 채널을 따릅니다.

## 추가 문서 / Further Documentation

| 문서 / Document | 경로 / Path |
|---|---|
| 프로젝트 지식 베이스 | [AGENTS.md](AGENTS.md) |
| 시스템 아키텍처 | [ARCHITECTURE.md](ARCHITECTURE.md) |
| 코드 스타일 | [CODE_STYLE.md](CODE_STYLE.md) |
| 기여 절차 | [CONTRIBUTING.md](CONTRIBUTING.md) |
| 의존성 맵 | [DEPENDENCY_MAP.md](DEPENDENCY_MAP.md) |
| 코드 오너 / 별칭 | [OWNERS](OWNERS), [OWNERS_ALIASES](OWNERS_ALIASES) |
| CoreDNS 워크스페이스 | [103-coredns/README.md](103-coredns/README.md) |
| ELK 워크스페이스 | [105-elk/terraform/README.md](105-elk/terraform/README.md) |
| MCP Hub 워크스페이스 | [112-mcphub/README.md](112-mcphub/README.md) |
| Cloudflare 워크스페이스 | [300-cloudflare/README.md](300-cloudflare/README.md) |
| Cloudflare 요구사항 | [300-cloudflare/docs/requirements.md](300-cloudflare/docs/requirements.md) |
| Workers | [300-cloudflare/workers/](300-cloudflare/workers/) |
| 보조 스크립트 | [300-cloudflare/scripts/](300-cloudflare/scripts/), [105-elk/scripts/](105-elk/scripts/) |
| 문서 정책 | [docs/AGENTS.md](docs/AGENTS.md) |
| 테스트 정책 | [tests/AGENTS.md](tests/AGENTS.md) |

## 라이선스 / License

[LICENSE](LICENSE) 파일을 참조하세요. 워크스페이스별 추가 라이선스 조건이 있다면 해당 디렉터리의 안내를 우선합니다.