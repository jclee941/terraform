# jclee.me 홈랩 인프라 / jclee.me Homelab Infrastructure

[![Terraform 1.10.5](https://img.shields.io/badge/Terraform-1.10.5-7B42BC?logo=terraform&logoColor=white)](Makefile)
[![Build: Makefile](https://img.shields.io/badge/Build-Makefile-0277BD?logo=gnu&logoColor=white)](Makefile)
[![Status: Active](https://img.shields.io/badge/Status-Active-brightgreen)](#status)
[![License: See LICENSE](https://img.shields.io/badge/License-See%20LICENSE-blue)](LICENSE)

> Terraform 1.10.5로 Proxmox 홈랩을 코드로 정의하는 단일 저장소. 번호가 매겨진 워크스페이스(`100-pve`, `102-traefik`, `300-cloudflare` 등)에 LXC/VM, 내부 서비스, 외부 DNS를 분산 배치하고, 1Password `homelab` 볼트의 비밀을 공유 모듈로 주입합니다.
>
> *Single repository that defines the `jclee.me` Proxmox homelab with Terraform 1.10.5. Numbered workspaces (`100-pve`, `102-traefik`, `300-cloudflare` …) distribute LXC/VM, internal services, and external DNS, while the shared 1Password `homelab` vault feeds secrets through one module.*

## 한눈에 보기 / At a Glance

| 항목 / Item | 값 / Value | 근거 / Source |
|---|---|---|
| 도메인 / Domain | `jclee.me` | DNS, [103-coredns/README.md](103-coredns/README.md) |
| 사설 LAN / Private LAN | `<homelab-subnet>/24` (RFC1918 자리표시자) | `100-pve/envs/prod/hosts.tf` |
| Terraform | 1.10.5, 제약 `>= 1.7, < 2.0` | [Makefile](Makefile), [DEPENDENCY_MAP.md](DEPENDENCY_MAP.md) |
| 워크스페이스 / Workspaces | 12 Makefile 별칭, 번호 `80`–`400` | [Makefile](Makefile) |
| 비밀 / Secrets | 1Password vault `homelab` | [modules/shared/onepassword-secrets/](modules/shared/onepassword-secrets/) |
| 상태 백엔드 / State backend | 로컬, 워크스페이스 옆 | [ARCHITECTURE.md](ARCHITECTURE.md) |
| CI/CD | GitHub Actions, 동시성 그룹 직렬화 | [.github/workflows/](.github/workflows/) |
| 테스트 / Testing | `terraform test`, 프로바이더 모의 | [tests/AGENTS.md](tests/AGENTS.md), [Makefile](Makefile) |
| 상태 / Status | Active (개인 홈랩) | - |
| 라이선스 / License | [LICENSE](LICENSE) 참조 | - |

## 요청 흐름 / Request Flow

1. **호스트 변경** — 운영자가 `100-pve/envs/prod/hosts.tf`에서 LXC/VM 추가/리사이즈 (호스트·IP·VMID 단일 출처)
2. **로컬 검증** — `make SVC=pve init && make SVC=pve plan` 으로 드리프트와 계획 검토
3. **변경 푸시** — PR이 GitHub Actions 워크플로를 트리거, 동시성 그룹이 동일 워크스페이스 apply 직렬화
4. **비밀 주입** — CI 환경에서 `OP_VAULT=homelab`을 통해 공유 모듈이 자격증명 채움
5. **Tier 0 적용** — `100-pve`가 Proxmox 자원을 apply 후 `.tftpl` 파일을 `docker-compose.yml`, `Corefile`, `filebeat.yml` 등으로 렌더링
6. **인접 서비스** — Tier 1 워크스페이스(`102-traefik`, `105-elk`, `112-mcphub` 등)가 자기 서비스를 표준 시퀀스로 apply
7. **외부 반영** — `300-cloudflare`, `400-gcp`가 호스트 맵을 외부 DNS·터널·Workers에 반영

*Operating pattern: the operator edits the single host source of truth (`100-pve/envs/prod/hosts.tf`), Makefile targets plan/apply each workspace, GitHub Actions serializes via concurrency, and `100-pve` renders downstream `.tftpl` files so siblings stay consistent.*

## 목차 / Table of Contents

- [처음 읽을 파일 / First Files to Read](#처음-읽을-파일--first-files-to-read)
- [워크스페이스 카탈로그 / Workspace Catalog](#워크스페이스-카탈로그--workspace-catalog)
- [시작하기 / Quick Start](#시작하기--quick-start)
- [명령어 / Commands Reference](#명령어--commands-reference)
- [구성 / Configuration](#구성--configuration)
- [아키텍처 / Architecture](#아키텍처--architecture)
- [로컬 개발 / Local Development](#로컬-개발--local-development)
- [테스트 / Testing](#테스트--testing)
- [기여 / Contribution Guide](#기여--contribution-guide)
- [운영 / Maintainers &amp; Status](#운영--maintainers--status)
- [추가 문서 / Further Documentation](#추가-문서--further-documentation)
- [라이선스 / License](#라이선스--license)

---

## 처음 읽을 파일 / First Files to Read

| 목적 / Purpose | 파일 / File | 비고 / Notes |
|---|---|---|
| 저장소 지도 / Repo map | [AGENTS.md](AGENTS.md) | 운영 지식 베이스, `WHERE TO LOOK` 표 포함 |
| 의존성 그래프 / Dependency graph | [DEPENDENCY_MAP.md](DEPENDENCY_MAP.md) | 모듈·워크스페이스 간 관계 |
| 아키텍처 결정 / Architecture decisions | [ARCHITECTURE.md](ARCHITECTURE.md) | 계층, 데이터 흐름 |
| 호스트/IP/VMID | `100-pve/envs/prod/hosts.tf` | 단일 출처, 변경 출발점 |
| 코드 규약 / Code style | [CODE_STYLE.md](CODE_STYLE.md) | PR 전 필수 |
| 기여 절차 / Contribution | [CONTRIBUTING.md](CONTRIBUTING.md) | PR 정책, 워크스페이스 추가 절차 |
| 책임자 / Ownership | [OWNERS](OWNERS), [OWNERS_ALIASES](OWNERS_ALIASES) | 검토자 매핑 |

## 워크스페이스 카탈로그 / Workspace Catalog

번호 규칙 — `1–255` 내부 홈랩 인프라(LAN 내부 도달 가능), `300+` 외부 공급자. 빈 구간은 의도적 예약.

| 번호 / No. | 별칭 / Alias | 경로 / Path | 책임 / Responsibility | 핵심 자산 / Key Assets |
|---|---|---|---|---|
| 80 | `jclee` | `80-jclee/` | 개인 워크스테이션 골격 | `main.tf` |
| 100 | `pve` | `100-pve/terraform/` | Tier 0 Proxmox 오케스트레이터, 호스트 SSoT, `.tftpl` 중앙 렌더러 | `main.tf`, `envs/prod/hosts.tf` |
| 101 | `runner` | `101-runner/` | 템플릿 전용 GitHub Actions 러너 | `*.tftpl` |
| 102 | `traefik` | `102-traefik/terraform/` | Tier 1 리버스 프록시 | `main.tf`, `templates/*.yml.tftpl` |
| 103 | (없음) | `103-coredns/` | 템플릿 전용 분할 DNS | `templates/Corefile.tftpl`, `docker-compose.yml.tftpl`, `filebeat.yml.tftpl` |
| 105 | `elk` | `105-elk/terraform/` | Tier 1 ELK 스택 | `main.tf`, `templates/`, `scripts/`, `config/` |
| 112 | `mcphub` | `112-mcphub/` | 템플릿 전용 MCP Hub + 1Password Connect 자산 | `templates/`, `op-mcp-server/`, `config/`, `mcp_servers.json`, `validate_mcps.py` |
| 200 | `oc` | `200-oc/` | 보조 워크로드 | - |
| 215 | `synology` | `215-synology/` | Synology DSM 통합 (플랫 레이아웃 예외) | `main.tf` |
| 220 | `youtube` | `220-youtube/` | YouTube 자동화 | - |
| 300 | `cloudflare` | `300-cloudflare/terraform/` | 독립형 Cloudflare DNS·터널·Workers | `main.tf`, `scripts/`, `inventory/secrets.yaml`, `workers/` |
| 310 | `safetywallet` | `310-safetywallet/` | 외부 서비스 통합 | - |
| 400 | `gcp` | `400-gcp/` | GCP 통합 | - |

워크스페이스는 두 가지 유형입니다:

- **Terraform 워크스페이스** — `main.tf` 보유, `make SVC=<alias> plan/apply` 대상
- **템플릿 전용** — `100-pve`가 `.tftpl`을 중앙 렌더링, 자체 Terraform 진입점 없음 (`101-runner`, `103-coredns`, `112-mcphub`)

*Numbering convention: 1–255 internal LAN-reachable infrastructure; 300+ external providers; template-only workspaces have no Make alias and are rendered centrally by `100-pve`.*

## 시작하기 / Quick Start

사전 준비 / Prerequisites:

| 요구 / Requirement | 권장 / Recommended | 확인 방법 / Check |
|---|---|---|
| Terraform | 1.10.5 (제약 `>= 1.7, < 2.0`) | `terraform version` |
| Go | 1.22+ (스크립트 빌드용) | `go version` |
| 1Password CLI | v2 이상 | `op --version` |
| Proxmox API 토큰 | 홈랩 API 액세스 권한 | `cat ~/.config/proxmox/token` |
| Python | 3.11+ (`validate_mcps.py` 등) | `python3 --version` |

```bash
# 1. 저장소 클론
git clone <repo-url> homelab
cd homelab

# 2. 환경 변수 — 1Password + Proxmox 자격증명 주입
export OP_VAULT=homelab
export PROXMOX_VE_API_URL=<proxmox-api-url>
export PROXMOX_VE_API_TOKEN_ID=<token-id>
export PROXMOX_VE_API_TOKEN_SECRET=<token-secret>
# 그 외 워크스페이스별 자격증명은 modules/shared/onepassword-secrets/ 참조

# 3. 워크스페이스 초기화 (별칭 또는 풀 패스)
make SVC=cloudflare init
# 또는
make SVC=300-cloudflare/terraform init

# 4. 계획 검토 및 적용
make SVC=cloudflare plan
make SVC=cloudflare apply
```

워크스페이스별 사전 단계는 각 디렉터리의 `README.md` / `AGENTS.md`에 명시되어 있습니다 (예: `105-elk/terraform/README.md`, `300-cloudflare/README.md`).

## 명령어 / Commands Reference

모든 명령은 `make SVC=<alias|path> <target>` 패턴. 별칭 미정의 워크스페이스는 풀 경로도 허용.

| 타겟 / Target | 목적 / Purpose | 예 / Example |
|---|---|---|
| `init` | Terraform 초기화 | `make SVC=cloudflare init` |
| `plan` | 실행 계획, `tfpla`로 저장 | `make SVC=pve plan` |
| `apply` | 적용 | `make SVC=traefik apply` |
| `verify` | 검증 절차 | `make SVC=elk verify` |
| `lint`, `lint-go` | 정적 분석 (Terraform / Go) | `make SVC=pve lint` |
| `fmt` | 포맷 통일 (모든 `*.tf` 워크스페이스) | `make fmt` |
| `validate` | 워크스페이스 검증 | `make SVC=gcp validate` |
| `drift-check` | 드리프트 점검 | `make SVC=pve drift-check` |
| `backup` | 상태 백업 | `make SVC=synology backup` |
| `test`, `test-unit`, `test-integration`, `test-workspace` | 테스트 스위트 | `make SVC=elk test`, `make test-workspace SVC=pve` |
| `docs` | 문서 생성·갱신 | `make docs` |
| `pre-commit-install`, `pre-commit-run` | 사전 커밋 훅 설치/실행 | `make pre-commit-install` |
| `setup` | 초기 셋업 | `make setup` |
| `help` | 사용 가능한 타겟 목록 | `make help` |

워크스페이스 디렉터리는 `find . -name '*.tf'`로 자동 수집되므로 새 디렉터리를 추가해도 `fmt`/`validate`/`lint`가 자동으로 인식합니다.

## 구성 / Configuration

### 비밀 / Secrets

- 단일 출처는 1Password 볼트 `homelab`. [modules/shared/onepassword-secrets/](modules/shared/onepassword-secrets/)가 Terraform 입력으로 주입.
- 환경 변수 `OP_VAULT`는 모든 워크스페이스에서 일관되게 사용.
- 워크스페이스별 `terraform.tfvars`는 비밀을 직접 보관하지 않고 1Password 항목 참조만 유지.

### 호스트 단일 출처 / Host Single Source of Truth

- LXC/VM 호스트, IP, VMID는 모두 `100-pve/envs/prod/hosts.tf`가 관리.
- 후속 워크스페이스는 이 hosts 파일을 템플릿 변수로 소비 (백엔드 IP, DNS 트리거 등).

### 시크릿 인벤토리 / Secret Inventory

- 워크스페이스별 인벤토리가 키와 1Password 참조를 매핑 (예: [300-cloudflare/inventory/secrets.yaml](300-cloudflare/inventory/secrets.yaml)).

### 빌드 변수 / Build Variables

- 저장소 루트의 [`build.env`](build.env)에 공유 빌드 환경 변수 정의. 워크스페이스별 추가 변수는 `variables.tf` 참조.

## 아키텍처 / Architecture

| 계층 / Layer | 역할 / Role | 구성 요소 / Components |
|---|---|---|
| Tier 0 — 오케스트레이터 | Proxmox 자원·템플릿 중앙 제어 | `100-pve` (호스트 SSoT, `.tftpl` 렌더러) |
| Tier 1 — 내부 서비스 | 홈랩 LAN 내부 동작 | `102-traefik`, `103-coredns`, `105-elk`, `112-mcphub` |
| Tier 1 — 보조 워크로드 | 워크스테이션, 외부 기기 통합 | `80-jclee`, `215-synology`, `220-youtube` |
| Tier 1 — 보조 CI/Workflow | 런너 이미지 | `101-runner` |
| 외부 / External | 홈랩 밖 DNS·클라우드 | `300-cloudflare`, `310-safetywallet`, `400-gcp` |
| 공유 / Shared | 재사용 모듈 | `modules/{proxmox,shared,cloudflare,elasticstack}` |

핵심 흐름 / Core flow:

1. `100-pve`가 호스트 맵을 입력으로 받아 Proxmox 자원을 apply — VMID·IP는 동시에 다른 워크스페이스의 입력으로 노출
2. 호스트 결과를 토대로 `100-pve`가 `.tftpl` 파일을 `docker-compose.yml`, `Corefile`, `filebeat.yml`, `logstash.conf` 등으로 렌더링
3. `102-traefik`, `105-elk` 등 Tier 1 워크스페이스가 자기 서비스를 표준 시퀀스로 apply (라우팅은 hosts 맵에서 backend IP만 참조)
4. `300-cloudflare`는 호스트 맵을 외부 DNS 레코드·터널·Workers에 반영 (`scripts/collect.go`, `generate-bindings.go`, `deploy-worker.go` 등 자체 스크립트 보유)
5. GitHub Actions 동시성 그룹이 동일 워크스페이스의 동시 apply를 차단해 상태 파일 경합을 제거
6. CI 진입점과 PR 규칙은 [CONTRIBUTING.md](CONTRIBUTING.md) 및 [.github/workflows/](.github/workflows/) 참조

*Architecture in brief: `100-pve` (Tier 0) owns the host map and renders `.tftpl` files; Tier 1 (`102-traefik`, `105-elk`, `112-mcphub`) consumes the rendered outputs; external workspaces (`300-cloudflare`, `400-gcp`) sit outside the LAN and share only secrets and code-style conventions.*

상세 결정은 [ARCHITECTURE.md](ARCHITECTURE.md), 의존성 그래프는 [DEPENDENCY_MAP.md](DEPENDENCY_MAP.md) 참조.

## 로컬 개발 / Local Development

| 영역 / Area | 권장 절차 / Recommended Workflow |
|---|---|
| 코드 스타일 | [CODE_STYLE.md](CODE_STYLE.md) 준수, 변경 후 `make fmt` |
| 새 워크스페이스 | `NNN-svc/` 디렉터리 생성, Makefile `ALIAS_*` 매핑 추가, `SVC` 검증 |
| 환경 격리 | 워크스페이스별 로컬 상태, 동시 작업은 별 디렉터리(또는 워크트리) 사용 |
| 변경 전 백업 | `make SVC=<ws> backup` |
| 변경 후 점검 | `make SVC=<ws> drift-check` → `make SVC=<ws> verify` |
| 시크릿 점검 | 변수 파일이 평문 비밀을 갖지 않는지 grep (예: `password|token|secret`) |
| LXC/VM 변경 | `100-pve/envs/prod/hosts.tf` 한 곳에서만 수정, 후속 워크스페이스는 자동 반영 확인 |
| 템플릿 검증 | `*.tftpl` 변경 후 `100-pve` 렌더링 결과를 인접 워크스페이스에서 dry-run |

사전 커밋 훅은 `make pre-commit-install`로 설치하고 `make pre-commit-run`으로 수동 실행할 수 있습니다.

## 테스트 / Testing

- 기본 프레임워크는 네이티브 `terraform test`. 프로바이더 호출은 기본적으로 모의(mock).
- Makefile이 테스트 부분 집합을 실행:
  - `make SVC=<ws> test` — 통합
  - `make SVC=<ws> test-unit`
  - `make SVC=<ws> test-integration`
  - `make SVC=<ws> test-workspace`
- 표준 모듈 테스트는 [modules/](modules/) 워크스페이스 디렉터리에서, 정책은 [tests/AGENTS.md](tests/AGENTS.md)에서 확인.
- 추가 자동 점검:
  - [112-mcphub/validate_mcps.py](112-mcphub/validate_mcps.py) — MCP 서버 구성 정합성
  - Go 스크립트는 각 디렉터리의 `scripts/`에 위치 ([105-elk/scripts/](105-elk/scripts/), [300-cloudflare/scripts/](300-cloudflare/scripts/))

## 기여 / Contribution Guide

1. 워크스페이스 디렉터리와 Makefile `ALIAS_<name>`을 함께 추가·수정.
2. 변수/출력에 명시적 타입과 설명을 부여 (anti-pattern 회피).
3. PR 전에 `make fmt && make SVC=<ws> validate && make SVC=<ws> lint` 통과.
4. 새 워크스페이스 번호 규칙 준수 — 내부 `1–255`, 외부 `300+`.
5. `*.tftpl` 변경은 인접 워크스페이스의 dry-run 결과를 PR에 첨부.
6. 비밀 평문 노출 금지 — 1Password 참조로만 작성.
7. 상세 절차는 [CONTRIBUTING.md](CONTRIBUTING.md), 스타일은 [CODE_STYLE.md](CODE_STYLE.md) 참조.

## 운영 / Maintainers & Status

| 항목 / Item | 값 / Value |
|---|---|
| 상태 / Status | Active (개인 홈랩) |
| 책임자 / Owners | [OWNERS](OWNERS), [OWNERS_ALIASES](OWNERS_ALIASES) |
| 지원 채널 / Support | 홈랩 사내 채팅, [AGENTS.md](AGENTS.md) 트러블슈팅 섹션 |
| 주요 정책 / Policy | [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_STYLE.md](CODE_STYLE.md), [ARCHITECTURE.md](ARCHITECTURE.md), [DEPENDENCY_MAP.md](DEPENDENCY_MAP.md) |

## 추가 문서 / Further Documentation

루트 문서:

- [AGENTS.md](AGENTS.md) — 운영 에이전트용 전역 지식 베이스 (`WHERE TO LOOK`, `CODE MAP`)
- [ARCHITECTURE.md](ARCHITECTURE.md) — 아키텍처 결정, 계층, 데이터 흐름
- [DEPENDENCY_MAP.md](DEPENDENCY_MAP.md) — 모듈·워크스페이스 의존성 그래프
- [CONTRIBUTING.md](CONTRIBUTING.md) — PR 정책, 워크스페이스 추가 절차
- [CODE_STYLE.md](CODE_STYLE.md) — Terraform·Go 스타일 규약
- [OWNERS](OWNERS), [OWNERS_ALIASES](OWNERS_ALIASES) — 책임자 매핑

워크스페이스별 문서:

- [103-coredns/README.md](103-coredns/README.md), [103-coredns/AGENTS.md](103-coredns/AGENTS.md)
- [105-elk/terraform/README.md](105-elk/terraform/README.md), [105-elk/AGENTS.md](105-elk/AGENTS.md), [105-elk/terraform/AGENTS.md](105-elk/terraform/AGENTS.md), [105-elk/config/AGENTS.md](105-elk/config/AGENTS.md), [105-elk/templates/AGENTS.md](105-elk/templates/AGENTS.md), [105-elk/scripts/AGENTS.md](105-elk/scripts/AGENTS.md)
- [112-mcphub/README.md](112-mcphub/README.md), [112-mcphub/AGENTS.md](112-mcphub/AGENTS.md), [112-mcphub/config/AGENTS.md](112-mcphub/config/AGENTS.md), [112-mcphub/templates/AGENTS.md](112-mcphub/templates/AGENTS.md), [112-mcphub/op-mcp-server/AGENTS.md](112-mcphub/op-mcp-server/AGENTS.md)
- [300-cloudflare/README.md](300-cloudflare/README.md), [300-cloudflare/AGENTS.md](300-cloudflare/AGENTS.md), [300-cloudflare/scripts/AGENTS.md](300-cloudflare/scripts/AGENTS.md), [300-cloudflare/workers/AGENTS.md](300-cloudflare/workers/AGENTS.md), [300-cloudflare/workers/synology-proxy/AGENTS.md](300-cloudflare/workers/synology-proxy/AGENTS.md), [300-cloudflare/docs/requirements.md](300-cloudflare/docs/requirements.md)

## 라이선스 / License

[LICENSE](LICENSE) 파일 참조. 본 저장소를 외부에 배포할 때는 라이선스 전문을 함께 제공합니다.