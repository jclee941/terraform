# jclee.me 홈랩 Terraform 인프라 / Terraform Homelab Infrastructure

[![Terraform](https://img.shields.io/badge/Terraform-1.10.5-7B42BC?logo=terraform&logoColor=white)](.)
[![Makefile](https://img.shields.io/badge/Build-Makefile-0277BD?logo=gnu&logoColor=white)](Makefile)
[![Secrets](https://img.shields.io/badge/Secrets-1Password-1572B6)](.)
[![CI](https://img.shields.io/badge/CI-GitHub_Actions-2088FF?logo=github-actions&logoColor=white)](.github/workflows/)
[![Status](https://img.shields.io/badge/Status-Active-brightgreen)](.)
[![License](https://img.shields.io/badge/License-See%20LICENSE-blue)](LICENSE)

## 요약 / Summary

**한국어.** `jclee.me` 홈랩을 코드로 정의·유지하는 Terraform 모노레포입니다. Proxmox 위에서 운영되는 LXC/VM 플릿, 내부 네트워크(Traefik, CoreDNS, ELK, MCP Hub, Synology, YouTube, Open Cloud 등) 그리고 Cloudflare·GCP 같은 외부 서비스를 **번호가 매겨진 워크스페이스** 단위로 프로비저닝합니다. 모든 비밀은 1Password 볼트 `homelab`에서 주입하며, 상태 백엔드는 로컬에 두고 GitHub Actions의 동시성 제어로 직렬화합니다. 일부 워크스페이스(`103-coredns`, `112-mcphub`)는 템플릿 전용으로, `100-pve`가 `.tftpl` 파일을 렌더링해 서비스 컨피그를 생성합니다.

**English.** A Terraform monorepo that provisions the `jclee.me` homelab as code: a Proxmox LXC/VM fleet, internal services (Traefik, CoreDNS, ELK, MCP Hub, Synology, Open Cloud, YouTube), and external providers (Cloudflare, GCP). Secrets come from the 1Password `homelab` vault, state is local, and GitHub Actions concurrency serializes applies. A few workspaces are template-only — `100-pve` renders their `.tftpl` configs centrally.

## 한눈에 보기 / At a Glance

| 항목 / Item | 값 / Value |
|---|---|
| 도메인 / Domain | `jclee.me` |
| 사설 LAN / Private LAN | RFC1918 홈랩 서브넷 (`<homelab-subnet>` 자리표시자) |
| Terraform | 1.10.5 (제약: `>= 1.7, < 2.0`) |
| 워크스페이스 / Workspaces | 13개의 번호 디렉터리, 12개의 Makefile 별칭 |
| 모듈 진입점 / Module entry points | 10 (`modules/{proxmox,shared,cloudflare,elasticstack}`) |
| 비밀 저장소 / Secrets | 1Password vault `homelab` (모듈 `modules/shared/onepassword-secrets/`) |
| CI/CD | GitHub Actions (동시성 그룹으로 직렬화) |
| 상태 백엔드 / State backend | 로컬 — `100-pve/terraform/`, `105-elk/`만 예외적으로 보유 |
| 라이선스 / License | [LICENSE](LICENSE) |

## 운영자 흐름 / Operator Flow

1. 별칭 확인 — `grep '^ALIAS_' Makefile` 또는 아래 [워크스페이스 별칭](#워크스페이스-별칭--workspace-aliases) 표 참고.
2. 코드 수정 — 호스트/IP/VMID는 `100-pve/envs/prod/hosts.tf`를 SSoT로 사용.
3. 검증 — `make fmt validate lint SVC=<alias>`.
4. 계획 — `make plan SVC=<alias>` (출력은 `tfpla`).
5. 적용 — `make apply SVC=<alias>` (CI에서는 `merge to master`로 트리거).
6. 사후 점검 — `make drift-check verify SVC=<alias>`, `make test`로 회귀 테스트.

## 목적 / Purpose

- 단일 진실 공급원(SSoT)으로 호스트·IP·VMID를 정의하고, 같은 호스트 맵으로 모든 템플릿을 렌더링.
- 외부 서비스를 Terraform으로 일관되게 관리해 CLI/API 호출을 IaC로 대체.
- 1Password 기반 시크릿 인젝션으로 평문 비밀 커밋을 차단.
- CI/CD 동시성 직렬화로 부분 적용·드리프트를 방지.

## 패키지 구성 / Package Contents

저장소 최상위 구조는 아래와 같습니다(스냅샷에 실제로 존재하는 경로만 반영).

```text
/
├── AGENTS.md
├── ARCHITECTURE.md
├── CODE_STYLE.md
├── CONTRIBUTING.md
├── DEPENDENCY_MAP.md
├── LICENSE
├── Makefile
├── README.md
├── build.env
├── 103-coredns/                # Tier 2 — Template-only split DNS (Corefile, docker-compose, filebeat)
│   ├── AGENTS.md
│   ├── README.md
│   └── templates/
│       ├── AGENTS.md
│       ├── Corefile.tftpl
│       ├── docker-compose.yml.tftpl
│       └── filebeat.yml.tftpl
├── 105-elk/                    # Tier 1 — ELK 스택 (Terraform + 템플릿 + 스크립트 + 컨피그)
│   ├── AGENTS.md
│   ├── docker-compose.yml
│   ├── ilm-policy.json
│   ├── scripts/
│   │   ├── remove-promtail
│   │   ├── remove-promtail.go
│   │   ├── setup-ilm.go
│   │   └── setup-watcher.go
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
│       ├── checks.tf
│       ├── main.tf
│       ├── onepassword.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── validation.tf
│       ├── variables.tf
│       └── versions.tf
├── 112-mcphub/                 # Tier 2 — MCP Hub + 1Password Connect
│   ├── AGENTS.md
│   ├── Dockerfile.dev-browser
│   ├── Dockerfile.playwright
│   ├── Dockerfile.proxmox
│   ├── README.md
│   ├── mcp_servers.json
│   ├── validate_mcps.py
│   ├── op-mcp-server/
│   │   ├── AGENTS.md
│   │   ├── index.mjs
│   │   ├── package-lock.json
│   │   └── package.json
│   ├── config/
│   │   ├── AGENTS.md
│   │   ├── entrypoint-patch.go
│   │   ├── filebeat.yml
│   │   ├── patch-placeholder.cjs
│   │   └── patch-sdk-schema.cjs
│   └── templates/
│       ├── AGENTS.md
│       ├── docker-compose-op-connect.yml.tftpl
│       ├── docker-compose.yml.tftpl
│       ├── filebeat.yml.tftpl
│       └── mcp_settings.json.tftpl
└── 300-cloudflare/             # External — Cloudflare Terraform + Workers + 스크립트
    ├── AGENTS.md
    ├── README.md
    ├── inventory/
    │   └── secrets.yaml
    ├── scripts/
    │   ├── AGENTS.md
    │   ├── audit.go
    │   ├── collect.go
    │   ├── deploy-worker.go
    │   ├── generate-bindings.go
    │   └── sync.go
    ├── docs/
    │   └── requirements.md
    └── workers/
        ├── AGENTS.md
        └── synology-proxy/
            ├── AGENTS.md
            └── package-lock.json
```

> 참고 / Note: AGENTS.md에 언급된 추가 워크스페이스(`80-jclee`, `100-pve`, `101-runner`, `102-traefik`, `200-oc`, `215-synology`, `220-youtube`, `310-safetywallet`, `400-gcp`), `modules/`, `tests/`, `scripts/`, `docs/`, `.github/`는 전체 저장소에는 존재하지만 이 스냅샷 트리에는 포함되지 않았습니다. 위 표의 별칭 경로와 [워크스페이스 티어](#워크스페이스-티어--workspace-tiers) 표는 Makefile과 AGENTS.md에서 가져온 메타데이터입니다.

## 먼저 읽을 파일 / First Files to Read

| 순서 / # | 파일 / File | 이유 / Why |
|---|---|---|
| 1 | [ARCHITECTURE.md](ARCHITECTURE.md) | 전체 토폴로지와 서비스 관계 한눈에 파악 |
| 2 | [Makefile](Makefile) | 명령어 계약, ALIAS 맵, 워크스페이스 해석 규칙 확인 |
| 3 | [DEPENDENCY_MAP.md](DEPENDENCY_MAP.md) | 모듈 의존성 그래프와 템플릿 인벤토리 |
| 4 | [CODE_STYLE.md](CODE_STYLE.md) | 명명·구조·변수 규칙 |
| 5 | `100-pve/envs/prod/hosts.tf` | 호스트/IP/VMID SSoT (스냅샷에 미포함 시 Makefile 경로 참고) |
| 6 | `.github/workflows/` | CI 정책, 자동 적용 트리거 |

## 진입점 / API & Entry Points

| 영역 / Area | 진입점 / Entry Point |
|---|---|
| 코어 플릿 오케스트레이터 | `100-pve/terraform/main.tf`, `100-pve/envs/prod/hosts.tf` |
| Tier 1 앱 | `102-traefik/terraform/main.tf`, `105-elk/terraform/main.tf` |
| 외부 프로바이더 | `215-synology/main.tf`, `300-cloudflare/terraform/main.tf` |
| Proxmox 모듈 | `modules/proxmox/*/main.tf` |
| Cloudflare 모듈 | `modules/cloudflare/tunnel/main.tf` |
| Elastic Stack 모듈 | `modules/elasticstack/*/main.tf` |
| 비밀 검색 모듈 | `modules/shared/onepassword-secrets/` |
| MCP Hub 검증 | `112-mcphub/validate_mcps.py` (Python 정적 검증) |
| Cloudflare Workers | `300-cloudflare/workers/*/src/index.ts` |
| 보조 도구 | `scripts/validate-docs/main.go`, `scripts/audit-workflows.go`, `300-cloudflare/scripts/collect.go` |

## 워크스페이스 티어 / Workspace Tiers

적용 순서는 위 → 아래이며, Tier 0이 항상 먼저 적용되어야 합니다.

| 티어 / Tier | 워크스페이스 / Workspaces | 책임 / Responsibility |
|---|---|---|
| **Tier 0 — Core** | `100-pve` | Proxmox 오케스트레이터, 호스트/IP SSoT, `.tftpl` 렌더링 |
| **Tier 1 — Infra** | `102-traefik`, `105-elk` | 리버스 프록시 + 관측성(ELK) |
| **Tier 2 — Apps** | `103-coredns`, `112-mcphub`, `200-oc`, `215-synology`, `220-youtube` | 도메인 서비스 (일부는 템플릿 전용) |
| **External** | `300-cloudflare`, `310-safetywallet`, `400-gcp` | 외부 프로바이더 (Tier 0에 의존하지 않음) |
| **Personal** | `80-jclee`, `101-runner` | 개인 워크스테이션 스켈레톤, CI 러너 템플릿 |

## 워크스페이스 별칭 / Workspace Aliases

Makefile의 `ALIAS_*` 맵 기준.

| 별칭 / Alias | 경로 / Path | 비고 / Note |
|---|---|---|
| `jclee` | `80-jclee` | 개인 워크스테이션 |
| `pve` | `100-pve/terraform` | Tier 0 코어 |
| `runner` | `101-runner` | 템플릿 전용 |
| `traefik` | `102-traefik/terraform` | Tier 1 |
| `elk` | `105-elk/terraform` | Tier 1, 상태 보유 |
| `mcphub` | `112-mcphub` | 템플릿 전용 |
| `oc` | `200-oc` | Tier 2 |
| `synology` | `215-synology` | 플랫 레이아웃 예외 |
| `youtube` | `220-youtube` | Tier 2 |
| `cloudflare` | `300-cloudflare/terraform` | External |
| `safetywallet` | `310-safetywallet` | External |
| `gcp` | `400-gcp` | External |

> `103-coredns`는 Makefile 별칭이 없으며, `100-pve`가 직접 템플릿을 렌더링합니다.

## 모듈 인벤토리 / Module Inventory

| 모듈 / Module | 위치 / Path | 진입점 / Entry Point |
|---|---|---|
| Proxmox (VM/LXC 등) | `modules/proxmox/*/` | `main.tf` |
| Shared (1Password 등) | `modules/shared/onepassword-secrets/` | 모듈 호출 |
| Cloudflare (터널 등) | `modules/cloudflare/tunnel/` | `main.tf` |
| Elastic Stack | `modules/elasticstack/*/` | `main.tf` |

## 빠른 시작 / Quick Start

사전 준비: Terraform 1.10.5, `make`, 선택적으로 Go(스크립트), Python 3(`validate_mcps.py`), pre-commit, 1Password CLI.

```bash
# 도움말 / Help
make help

# 사용 가능한 워크스페이스 / List workspaces
grep '^ALIAS_' Makefile
ls -d [0-9]*/

# 포맷 / Format
make fmt

# 검증 / Validate
make validate SVC=pve

# 린트 / Lint
make lint
make lint-go

# 플랜 / Plan
make plan SVC=pve            # tfpla 산출물 생성

# 적용 / Apply
make apply SVC=pve

# 검증·드리프트 / Verify & drift
make verify SVC=pve
make drift-check

# 테스트 / Test
make test
make test-unit
make test-integration
make test-workspace

# 문서 / Docs
make docs

# 백업 / Backup
make backup

# Pre-commit
make pre-commit-install
make pre-commit-run

# 초기화 / Setup
make setup
```

> `SVC`는 Makefile 별칭(`pve`, `elk`, `cloudflare` 등) 또는 전체 경로(`100-pve`, `105-elk/terraform`) 모두 허용합니다. ALIAS 맵에 정의된 경우 별칭이 우선이며, 미정의 시 `SVC`를 그대로 경로로 사용합니다.

## 환경 설정 / Configuration

| 항목 / Item | 출처 / Source | 참고 / Notes |
|---|---|---|
| Terraform 버전 | `terraform { required_version = "~> 1.10" }` | `>= 1.7, < 2.0` |
| 비밀 / Secrets | 1Password vault `homelab` | `modules/shared/onepassword-secrets/` 모듈 사용, 평문 커밋 금지 |
| 환경 변수 / Env vars | [build.env](build.env) | CI는 `.github/workflows/` 참조 |
| 상태 백엔드 / State backend | 로컬 | 예외적으로 `100-pve/terraform/`, `105-elk/`만 `tfpla`/`terraform.tfstate*` 보유 — 일반화 금지 |
| 변수 명명 | `snake_case`, 설명 + 명시적 타입 필수 | 단일 인스턴스 리소스는 `resource "x" "this"` |
| 파일 명명 | Terraform은 `snake_case`, 템플릿/스크립트는 `kebab-case` | 앱 로직은 `templates/*.tftpl`에 둠 |

## 명령어 레퍼런스 / Commands Reference

`.PHONY`에 선언된 모든 타겟:

| 명령 / Command | 설명 / Description |
|---|---|
| `make init SVC=<alias>` | Terraform 초기화 |
| `make plan SVC=<alias>` | `tfpla`로 계획 저장 |
| `make apply SVC=<alias>` | 계획 적용 |
| `make verify SVC=<alias>` | 적용 후 검증 |
| `make fmt` | 모든 `.tf` 포맷 (nested `terraform/` 포함) |
| `make validate SVC=<alias>` | 워크스페이스 검증 |
| `make lint` | 통합 린트 |
| `make lint-go` | Go 스크립트 린트 |
| `make drift-check` | 상태 드리프트 검사 |
| `make test` | 모든 테스트 |
| `make test-unit` | 단위 테스트 |
| `make test-integration` | 통합 테스트 |
| `make test-workspace` | 워크스페이스 테스트 |
| `make docs` | 모듈 README 재생성 |
| `make backup` | 상태 백업 |
| `make pre-commit-install` | pre-commit 훅 설치 |
| `make pre-commit-run` | pre-commit 훅 실행 |
| `make setup` | 환경 부트스트랩 |
| `make help` | 사용 가능한 타겟 안내 |

## 로컬 개발 / Local Development

1. **도구 설치 / Toolchain** — Terraform 1.10.5, `make`, Go(스크립트 빌드용), Python 3.x(`validate_mcps.py`), pre-commit, 1Password CLI.
2. **1Password 인증 / Authenticate 1Password** — `op signin` 후 vault `homelab`에 접근 가능한 세션 확보. CI는 서비스 계정 토큰 사용.
3. **작업 전 검사 / Pre-flight** — `make fmt && make validate SVC=<alias> && make lint`.
4. **호스트 변경 / Host changes** — `100-pve/envs/prod/hosts.tf`만 수정. 다른 워크스페이스는 호스트 맵을 통해 주입받음.
5. **템플릿 변경 / Template changes** — `{NNN}-{svc}/templates/*.tftpl` 수정. 렌더링은 `100-pve`가 담당.
6. **PR 제출 / Open PR** — `.github/workflows/`가 동시성 그룹으로 적용 순서를 보장. `merge to master` 시 자동 적용.

## 테스트 / Testing

- **네이티브 `terraform test`** 사용. `tests/` 디렉터리의 테스트는 프로바이더 모킹이 기본.
- **Make 타겟** — `make test`, `make test-unit`, `make test-integration`, `make test-workspace`.
- **MCP Hub** — `python 112-mcphub/validate_mcps.py`로 MCP 서버 정의를 정적 검증.
- **ELK** — `105-elk/scripts/setup-ilm.go`, `setup-watcher.go`, `remove-promtail.go`로 인덱스 라이프사이클·워처를 점검.
- **Cloudflare** — `300-cloudflare/scripts/{audit,collect,sync,deploy-worker,generate-bindings}.go`로 감사·동기화·배포 검증.

## 기여 / Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) 및 [CODE_STYLE.md](CODE_STYLE.md) 참조. 핵심 원칙:

- `snake_case` for Terraform identifiers, `kebab-case` for templates/scripts.
- 모든 변수/출력에 설명, 변수는 명시적 타입.
- 새 워크스페이스는 `Makefile`의 `ALIAS_*`와 [워크스페이스 티어](#워크스페이스-티어--workspace-tiers) 표를 함께 갱신.
- 1Password 비밀은 평문으로 절대 커밋하지 않음.
- ADR은 append-only.

## 운영자 / Maintainers & Points of Contact

| 역할 / Role | 위치 / Location |
|---|---|
| 소유자 / Owner | 저장소 관리자 |
| 도메인 / Domain | `jclee.me` |
| CI 정책 / CI policy | `.github/workflows/`, `.github/AGENTS.md` (저장소 내부 문서) |
| 아키텍처 결정 / ADRs | `docs/adr/` (append-only) |
| 운영 절차 / Runbooks | `docs/runbooks/` |

## 추가 문서 / Further Documentation

| 문서 / Document | 목적 / Purpose |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | 시스템 토폴로지, 서비스 관계 |
| [DEPENDENCY_MAP.md](DEPENDENCY_MAP.md) | 모듈 의존성 그래프, 템플릿 인벤토리 |
| [CODE_STYLE.md](CODE_STYLE.md) | 명명 규칙, 파일 조직, 변수 표준 |
| [CONTRIBUTING.md](CONTRIBUTING.md) | 기여 절차 |
| [LICENSE](LICENSE) | 라이선스 전문 |
| [103-coredns/README.md](103-coredns/README.md) | CoreDNS 템플릿 안내 |
| [105-elk/terraform/README.md](105-elk/terraform/README.md) | ELK Terraform 안내 |
| [112-mcphub/README.md](112-mcphub/README.md) | MCP Hub 안내 |
| [300-cloudflare/README.md](300-cloudflare/README.md) | Cloudflare 안내 |

## 도움말 / Getting Help

- 버그·기능 요청: 저장소 Issues.
- 인시던트 대응: `docs/runbooks/`.
- 결정 이력: `docs/adr/`.
- 워크스페이스별 운영 노트: 각 `AGENTS.md` (저장소 내부 AI 보조 문서).

## 라이선스 / License

[LICENSE](LICENSE) 파일 참조.
