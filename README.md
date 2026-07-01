# jclee.me 홈랩 Terraform 인프라 / jclee.me Homelab Terraform Infrastructure

[![Terraform](https://img.shields.io/badge/Terraform-1.10.5-7B42BC?logo=terraform&logoColor=white)](.)
[![Makefile](https://img.shields.io/badge/Build-Makefile-0277BD?logo=gnu&logoColor=white)](Makefile)
[![Secrets](https://img.shields.io/badge/Secrets-1Password-1572B6)](.)
[![CI](https://img.shields.io/badge/CI-GitHub_Actions-2088FF?logo=github-actions&logoColor=white)](.github/workflows/)
[![Status](https://img.shields.io/badge/Status-Active-brightgreen)](.)
[![License](https://img.shields.io/badge/License-See%20LICENSE-blue)](LICENSE)

## 개요 / Overview

`jclee.me` 홈랩을 코드로 정의하고 유지하기 위한 Terraform 모노레포입니다. Proxmox 위의 LXC/VM 플릿, 내부 서비스(Traefik, CoreDNS, ELK, MCP Hub, Synology, YouTube, Open Cloud 등), 그리고 Cloudflare·GCP 같은 외부 서비스를 **번호가 매겨진 워크스페이스** 단위로 프로비저닝합니다. 비밀은 1Password `homelab` 볼트에서 주입하고, 상태는 워크스페이스 옆 로컬에 두며, GitHub Actions 동시성 그룹이 apply 순서를 직렬화합니다. 일부 워크스페이스는 템플릿 전용이며 `100-pve`가 `.tftpl` 파일을 중앙에서 렌더링합니다.

This repository defines and maintains the `jclee.me` homelab as Terraform code. Numbered workspaces provision a Proxmox LXC/VM fleet, internal services (Traefik, CoreDNS, ELK, MCP Hub, Synology, YouTube, Open Cloud), and external providers (Cloudflare, GCP). Secrets are pulled from the 1Password `homelab` vault, state lives beside each workspace, and GitHub Actions concurrency groups serialize apply order. Template-only workspaces have their `.tftpl` files rendered centrally by `100-pve`.

## 한눈에 보기 / At a Glance

| 항목 / Item | 값 / Value |
|---|---|
| 도메인 / Domain | `jclee.me` |
| 사설 LAN / Private LAN | `<homelab-subnet>` 자리표시자 사용 (RFC1918) |
| Terraform | 1.10.5, 제약 `>= 1.7, < 2.0` |
| 워크스페이스 / Workspaces | NNN-번호 디렉터리, Makefile 별칭 12개 |
| 비밀 / Secrets | 1Password vault `homelab` |
| 상태 백엔드 / State backend | 로컬, 워크스페이스 옆 |
| CI/CD | GitHub Actions, 동시성 그룹 직렬화 |
| 상태 / Status | Active (개인 홈랩) |

## 요청 흐름 / Request Flow

1. 운영자가 `100-pve/envs/prod/hosts.tf`(호스트/IP/VMID SSoT) 또는 워크스페이스 `.tf`를 편집합니다.
2. `make SVC=<alias> plan`을 실행하여 변경 사항을 검토합니다.
3. PR이 GitHub Actions에서 동시성 그룹을 통해 다시 `plan`을 수행합니다.
4. 승인 후 `make SVC=<alias> apply`로 적용합니다.
5. 템플릿 전용 워크스페이스의 `.tftpl`은 `100-pve`가 중앙에서 렌더링합니다.

## 패키지 구성 / Package Contents

저장소 최상위 레이아웃:

```text
.
├── AGENTS.md              # 프로젝트 지식 베이스
├── ARCHITECTURE.md        # 아키텍처 상세
├── CODE_STYLE.md          # 코드 스타일 규칙
├── CONTRIBUTING.md        # 기여 절차
├── DEPENDENCY_MAP.md      # 의존성 매핑
├── LICENSE
├── Makefile               # 명령 계약(별칭 해석기)
├── OWNERS, OWNERS_ALIASES # 소유권 메타데이터
├── build.env              # 빌드 시점 환경 변수
├── 103-coredns/           # 템플릿 전용 split DNS
├── 105-elk/               # Tier 1 ELK 스택
├── 112-mcphub/            # 템플릿 전용 MCP Hub + 1Password Connect
└── 300-cloudflare/        # 외부 Cloudflare + Workers
```

워크스페이스는 `NNN-{svc}` 명명 규칙을 따릅니다. `1-255`는 내부 인프라, `300+`는 외부 서비스를 의미합니다. Makefile 별칭으로 짧은 이름(`pve`, `elk`, `traefik`, `cloudflare`, `gcp` 등)을 사용할 수 있고, 일부 워크스페이스는 `terraform/` 하위 디렉터리에 실제 `.tf` 파일을 둡니다.

| 계층 / Tier | 별칭 / Alias | 디렉터리 / Directory | 목적 / Purpose |
|---|---|---|---|
| Tier 0 | `jclee` | `80-jclee` | 개인 워크스테이션 스켈레톤 |
| Tier 0 | `pve` | `100-pve/terraform` | Proxmox 오케스트레이터, 호스트 SSoT |
| Tier 1 | `runner` | `101-runner` | 템플릿 전용 GitHub Actions 러너 |
| Tier 1 | `traefik` | `102-traefik/terraform` | 리버스 프록시 + 라우트 템플릿 |
| Tier 1 | (직접) | `103-coredns` | 템플릿 전용 split DNS |
| Tier 1 | `elk` | `105-elk/terraform` | ELK 스택 (Terraform + 템플릿 + 스크립트) |
| Tier 1 | `mcphub` | `112-mcphub` | 템플릿 전용 MCP Hub + 1Password Connect 자산 |
| Tier 2 | `oc` | `200-oc` | Open Cloud |
| Tier 2 | `synology` | `215-synology` | Synology 통합 (flat 구조 예외) |
| Tier 2 | `youtube` | `220-youtube` | YouTube 자동화 |
| 외부 / Ext. | `cloudflare` | `300-cloudflare/terraform` | Cloudflare DNS/터널/Workers |
| 외부 / Ext. | `safetywallet` | `310-safetywallet` | SafetyWallet 외부 제공자 |
| 외부 / Ext. | `gcp` | `400-gcp` | GCP 외부 제공자 |

진입 모듈은 `modules/{proxmox,shared,cloudflare,elasticstack}/` 아래에 있으며, 자세한 워크스페이스 맵은 [`AGENTS.md`](AGENTS.md)를 참조하세요.

## 상태 / Status

- **운영 상태 / Production status:** Active — 개인 홈랩, 활발히 유지보수 중.
- **폐기 여부 / Deprecated:** 아니오 / No.
- **호환성 / Compatibility:** Terraform `>= 1.7, < 2.0` (1.10.5 검증).
- **테스트 / Tests:** 네이티브 `terraform test`, 제공자 모의(mock) 기본.

## 먼저 읽을 파일 / First Files to Read

운영자/기여자가 가장 먼저 살펴봐야 할 문서:

- [`README.md`](README.md) — 이 문서.
- [`AGENTS.md`](AGENTS.md) — 프로젝트 지식 베이스, 워크스페이스 맵, 규칙.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — 아키텍처 상세.
- [`DEPENDENCY_MAP.md`](DEPENDENCY_MAP.md) — 워크스페이스 간 의존성.
- [`CODE_STYLE.md`](CODE_STYLE.md) — Terraform/스크립트 스타일 가이드.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — PR 절차.
- [`Makefile`](Makefile) — 명령 계약과 별칭 해석기.
- [`OWNERS`](OWNERS), [`OWNERS_ALIASES`](OWNERS_ALIASES) — 리뷰 권한.
- [`build.env`](build.env) — 빌드 시점 환경 변수.

## 아키텍처 / Architecture

| 영역 / Area | 진입점 / Entry Point | 비고 / Notes |
|---|---|---|
| 코어 플릿 | `100-pve/terraform/main.tf`, `100-pve/envs/prod/hosts.tf` | `hosts.tf`가 호스트/IP/VMID의 단일 진실 공급원(SSoT) |
| Tier 1 앱 | `102-traefik/terraform/main.tf`, `105-elk/terraform/main.tf` | Traefik 라우트는 `templates/*.yml.tftpl`에서 생성 |
| 외부 제공자 | `215-synology/main.tf`, `300-cloudflare/terraform/main.tf` | Cloudflare Access 자원은 제거됨 |
| 모듈 | `modules/proxmox/*/main.tf`, `modules/cloudflare/tunnel/main.tf`, `modules/elasticstack/*/main.tf` | 재사용 가능한 추상화 |
| 도구 | `scripts/validate-docs/main.go`, `scripts/audit-workflows.go`, `300-cloudflare/scripts/collect.go` | 문서 검증, 워크플로 감사, 자산 수집 |
| Workers | `300-cloudflare/workers/*/src/index.ts` | 예: `synology-proxy` |

흐름 요약:

1. `100-pve`가 호스트/IP/VMID SSoT를 보유하고 Tier 1 워크스페이스의 `.tftpl`을 렌더링합니다.
2. 각 Tier 1 워크스페이스는 자체 컨피그를 작성하며, 비밀은 1Password 모듈을 통해 주입됩니다.
3. 외부 워크스페이스(`300-cloudflare`, `400-gcp`)는 자체 `terraform/` 루트와 로컬 상태를 가집니다.
4. GitHub Actions가 PR마다 `plan`을 재실행하고 동시성 그룹으로 apply 순서를 직렬화합니다.
5. `215-synology`은 flat 구조의 명시적 예외로, 다른 워크스페이스 패턴을 따르지 않습니다.

## 빠른 시작 / Quickstart

### 사전 요구 사항 / Prerequisites

- Terraform `>= 1.7, < 2.0` (권장 1.10.5)
- `make`, `git`
- 1Password CLI + `homelab` 볼트 접근 권한
- Proxmox API 토큰 (내부 워크스페이스용)
- Cloudflare API 토큰 (`300-cloudflare`용)
- GCP 서비스 계정 (`400-gcp`용)

### 기본 워크플로 / Basic Workflow

```bash
# 저장소 클론
git clone <repo-url> terraform && cd terraform

# 별칭으로 plan
make SVC=pve plan         # → 100-pve/terraform
make SVC=elk plan         # → 105-elk/terraform
make SVC=mcphub plan      # → 112-mcphub
make SVC=cloudflare plan  # → 300-cloudflare/terraform

# 전체 경로로도 가능
make SVC=100-pve plan
make SVC=105-elk/terraform plan

# 직접 terraform 호출
cd 100-pve/terraform && terraform init && terraform plan -out=tfpla

# 저장소 전체 위생
make fmt
make validate
make lint
make test
```

Make 타겟은 `Makefile`에서 정의되며, `SVC`가 `ALIAS_*`에 매핑되면 자동으로 디렉터리를 해석합니다. 인식 가능한 별칭은 `jclee pve runner traefik elk mcphub oc synology youtube cloudflare safetywallet gcp`입니다.

## 설정 / Configuration

| 영역 / Area | 위치 / Location | 비고 / Notes |
|---|---|---|
| 비밀 / Secrets | 1Password vault `homelab` | 커밋된 값 금지. `modules/shared/onepassword-secrets/`를 통해 주입 |
| 백엔드 / Backend | 로컬, 워크스페이스 옆 | `105-elk`와 `100-pve/terraform`은 명시적 예외 |
| 변수 / Variables | 각 워크스페이스의 `variables.tf` | 설명 필수, 명시적 타입 권장 |
| 출력 / Outputs | 각 워크스페이스의 `outputs.tf` | 설명 필수 |
| 빌드 환경 / Build env | [`build.env`](build.env) | 빌드 시점 환경 변수 |
| 1Password 모듈 | `modules/shared/onepassword-secrets/` | 모든 비밀의 표준 진입점 |

## 명령어 참조 / Commands Reference

`Makefile`은 단일 명령 계약을 제공합니다. `SVC` 인자로 워크스페이스를 선택합니다.

| 타겟 / Target | 설명 / Description |
|---|---|
| `init` | `SVC` 워크스페이스 `terraform init` |
| `plan` | `terraform plan -out=tfpla` |
| `apply` | `terraform apply` |
| `verify` | 적용 후 검증 |
| `lint` | Terraform + Go 린트 |
| `lint-go` | Go 코드만 린트 |
| `fmt` | 모든 Terraform 워크스페이스 포맷 |
| `validate` | 모든 Terraform 워크스페이스 검증 |
| `drift-check` | 상태 드리프트 점검 |
| `test` | 통합 테스트 실행 |
| `test-unit` | 단위 테스트 실행 |
| `test-integration` | 통합 테스트 실행 |
| `test-workspace` | 워크스페이스 단위 테스트 |
| `backup` | 상태/산출물 백업 |
| `docs` | 문서 생성/검증 |
| `pre-commit-install` | pre-commit 훅 설치 |
| `pre-commit-run` | pre-commit 훅 실행 |
| `setup`, `help` | 환경 준비/도움말 |

별칭 예: `SVC=pve`, `SVC=elk`, `SVC=traefik`, `SVC=cloudflare`, `SVC=gcp`. 전체 별칭 목록은 `Makefile`의 `ALIAS_*` 정의를 참조하세요.

## 로컬 개발 / Local Development

```bash
# 1. 저장소 클론 후 진입
git clone <repo-url> terraform && cd terraform

# 2. pre-commit 설치
make pre-commit-install

# 3. 포맷/검증
make fmt
make validate

# 4. 변경할 워크스페이스 plan
make SVC=<alias> plan

# 5. 테스트
make test-unit
make test-integration
```

- **새 워크스페이스 추가:** `NNN-{svc}/` 디렉터리를 만들고, 필요 시 `Makefile`의 `ALIAS_*` 맵에 별칭을 등록합니다. `.tf`는 워크스페이스 루트 또는 `terraform/` 하위에 둘 수 있습니다.
- **새 모듈 추가:** `modules/{proxmox,shared,cloudflare,elasticstack}/` 아래에 둡니다.
- **비밀 추가:** 1Password `homelab` 볼트에 저장하고 `modules/shared/onepassword-secrets/`를 통해 주입합니다. 절대 커밋하지 마세요.
- **워크플로 정책:** `.github/AGENTS.md` 참조.

## 테스트 / Testing

- 네이티브 `terraform test`를 사용합니다.
- 기본적으로 제공자가 모의(mock) 처리됩니다.
- Make 타겟: `test-unit`, `test-integration`, `test-workspace`, `test`.
- 자세한 내용은 [`tests/AGENTS.md`](tests/AGENTS.md)를 참조하세요.

## 기여 / Contributing

기여 절차는 [`CONTRIBUTING.md`](CONTRIBUTING.md)를 따릅니다. PR 전 다음을 권장합니다:

```bash
make fmt
make validate
make test-unit
make pre-commit-run
```

워크플로/CI 정책은 [`.github/AGENTS.md`](.github/AGENTS.md)를 참조하세요. 코드 스타일은 [`CODE_STYLE.md`](CODE_STYLE.md)에 정의되어 있습니다 (`snake_case` Terraform 식별자, `kebab-case` 템플릿/스크립트, 단일 인스턴스 자원은 `resource "x" "this"`).

## 운영자 / Maintainers

리뷰 권한과 책임은 저장소 루트의 [`OWNERS`](OWNERS) 및 [`OWNERS_ALIASES`](OWNERS_ALIASES) 파일에 정의되어 있습니다. 도메인/네트워크 소유권에 대한 질문은 해당 파일을 먼저 확인하세요.

## 추가 문서 / Further Documentation

| 문서 / Document | 경로 / Path |
|---|---|
| 프로젝트 지식 베이스 | [`AGENTS.md`](AGENTS.md) |
| 아키텍처 상세 | [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| 의존성 매핑 | [`DEPENDENCY_MAP.md`](DEPENDENCY_MAP.md) |
| 코드 스타일 | [`CODE_STYLE.md`](CODE_STYLE.md) |
| 기여 절차 | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
| 테스트 정책 | [`tests/AGENTS.md`](tests/AGENTS.md) |
| 문서 정책 | [`docs/AGENTS.md`](docs/AGENTS.md) |
| 워크플로 정책 | [`.github/AGENTS.md`](.github/AGENTS.md) |
| Cloudflare 운영 | [`300-cloudflare/README.md`](300-cloudflare/README.md) |
| MCP Hub | [`112-mcphub/README.md`](112-mcphub/README.md) |
| CoreDNS | [`103-coredns/README.md`](103-coredns/README.md) |
| ELK | [`105-elk/README.md`](105-elk/README.md) |

## 라이선스 / License

저장소 루트의 [`LICENSE`](LICENSE) 파일을 참조하세요.