# jclee.me 홈랩 인프라 / jclee.me Homelab Infrastructure

[![Terraform](https://img.shields.io/badge/Terraform-1.10.5-7B42BC?logo=terraform&logoColor=white)](Makefile)
[![Build](https://img.shields.io/badge/Build-Makefile-0277BD?logo=gnu&logoColor=white)](Makefile)
[![Secrets](https://img.shields.io/badge/Secrets-1Password-1572B6)](modules/shared/onepassword-secrets/)
[![CI](https://img.shields.io/badge/CI-GitHub_Actions-2088FF?logo=github-actions&logoColor=white)](.github/workflows/)
[![Status](https://img.shields.io/badge/Status-Active-brightgreen)](#status)
[![License](https://img.shields.io/badge/License-See%20LICENSE-blue)](LICENSE)

## 개요

`jclee.me` 홈랩을 코드로 정의하고 운영하는 Terraform 인프라 레포지토리입니다. Proxmox 위의 LXC/VM 플릿, 내부 서비스(Traefik, CoreDNS, ELK, MCP Hub, Synology, YouTube 등), 그리고 Cloudflare·GCP 같은 외부 서비스를 **번호가 매겨진 워크스페이스** 단위로 프로비저닝합니다. 비밀은 1Password `homelab` 볼트에서 주입하고, 상태는 워크스페이스 옆 로컬에 두며, GitHub Actions 동시성 그룹이 apply 순서를 직렬화합니다. 일부 워크스페이스는 템플릿 전용이며 `100-pve`가 `.tftpl` 파일을 중앙에서 렌더링합니다.

## Overview

Numbered Terraform workspaces define and operate the `jclee.me` homelab: a Proxmox LXC/VM fleet, internal services (Traefik, CoreDNS, ELK, MCP Hub, Synology, YouTube), and external providers (Cloudflare, GCP). Secrets are pulled from the 1Password `homelab` vault, state lives beside each workspace, and GitHub Actions concurrency groups serialize apply order. Template-only workspaces have their `.tftpl` files rendered centrally by `100-pve`.

## 한눈에 보기 / At a Glance

| 항목 / Item | 값 / Value |
|---|---|
| 도메인 / Domain | `jclee.me` |
| 사설 LAN / Private LAN | `<homelab-subnet>/24` (RFC1918 자리표시자 / placeholder) |
| Terraform | 1.10.5, 제약 `>= 1.7, < 2.0` |
| 워크스페이스 / Workspaces | `NNN-` 번호 디렉터리, Makefile 별칭 12개 |
| 비밀 / Secrets | 1Password vault `homelab` |
| 상태 백엔드 / State backend | 로컬, 워크스페이스 옆 |
| CI/CD | GitHub Actions, 동시성 그룹 직렬화 |
| 상태 / Status | Active (개인 홈랩) |
| 라이선스 / License | [LICENSE](LICENSE) 참조 |

## 요청 흐름 / Request Flow

1. 운영자가 `100-pve/envs/prod/hosts.tf`에서 호스트/IP/VMID SSoT를 수정합니다.
2. `make plan SVC=pve` (또는 별칭) 로 Terraform 플랜을 생성합니다.
3. GitHub Actions가 동시성 그룹으로 직렬화해 apply를 실행합니다.
4. `100-pve`가 `templates/*.tftpl`을 렌더링해 서비스용 docker-compose·Corefile·filebeat 등을 호스트에 배포합니다.
5. 1Password `homelab` 볼트가 secrets를 환경변수로 주입합니다.

---

## 목차 / Table of Contents

- [Purpose / 패키지 구성](#purpose--패키지-구성)
- [Status](#status)
- [First Files to Read](#first-files-to-read)
- [API / Entry Points](#api--entry-points)
- [Quickstart](#quickstart)
- [Commands Reference](#commands-reference)
- [Configuration & Secrets](#configuration--secrets)
- [Architecture](#architecture)
- [Local Development & Testing](#local-development--testing)
- [Contribution](#contribution)
- [Maintainers / Contact](#maintainers--contact)
- [Further Documentation](#further-documentation)

## Purpose / 패키지 구성

홈랩 인프라를 단일 진실 공급원(SSoT) 으로 정의하고, 변경 사항을 코드 리뷰·PR·apply로 추적하기 위한 Terraform 모음입니다.

포함된 주요 워크스페이스:

| 워크스페이스 | 별칭 | 역할 |
|---|---|---|
| `80-jclee` | `jclee` | 개인 워크스테이션 스켈레톤 |
| `100-pve` | `pve` | Tier 0 Proxmox 오케스트레이터 + 호스트 SSoT |
| `101-runner` | `runner` | 템플릿 전용 GitHub Actions 러너 설정 |
| `102-traefik` | `traefik` | Tier 1 리버스 프록시 + 라우트 템플릿 |
| `103-coredns` | (없음) | 템플릿 전용 split DNS 설정 |
| `105-elk` | `elk` | Tier 1 ELK Terraform, 템플릿, 스크립트 |
| `112-mcphub` | `mcphub` | 템플릿 전용 MCP Hub + 1Password Connect 자산 |
| `200-oc` | `oc` | Open Cloud 워크스페이스 |
| `215-synology` | `synology` | 외부 Synology 연동 (flat 레이아웃 예외) |
| `220-youtube` | `youtube` | YouTube 자동화 워크스페이스 |
| `300-cloudflare` | `cloudflare` | Cloudflare DNS/터널/Workers |
| `310-safetywallet` | `safetywallet` | Safety Wallet 서비스 |
| `400-gcp` | `gcp` | GCP 프로젝트 프로비저닝 |

공통 모듈은 [modules/](modules/) 아래에 위치합니다. `modules/{proxmox,shared,cloudflare,elasticstack}/` 각각의 `main.tf`가 모듈 진입점입니다.

## Status

| 영역 | 상태 |
|---|---|
| 프로덕션 사용 | 개인 홈랩 (production-grade for a single-operator homelab) |
| 지원 / Support | Best-effort, 개인 유지보수 |
| 안정성 / Stability | Active 변경 중 (워크스페이스 추가/리팩터링 진행) |
| 폐기 여부 / Deprecated | 아니오 |
| 사용 가능 여부 | 운영 중 |

## First Files to Read

| 작업 / Task | 위치 / Location |
|---|---|
| 호스트/IP/VMID 변경 | [100-pve/envs/prod/hosts.tf](100-pve/envs/prod/hosts.tf), [100-pve/terraform/locals.tf](100-pve/terraform/locals.tf) |
| 서비스 설정 변경 | `{NNN}-{svc}/templates/*.tftpl` (예: `102-traefik/templates/`, `105-elk/templates/`) |
| Traefik 라우트 추가 | `102-traefik/templates/*.yml.tftpl` |
| ELK 파이프라인 | `105-elk/templates/logstash.conf.tftpl`, [modules/elasticstack/](modules/elasticstack/) |
| Cloudflare DNS/터널/Workers | [300-cloudflare/terraform/](300-cloudflare/terraform/), [modules/cloudflare/](modules/cloudflare/) |
| 비밀 조회 | [modules/shared/onepassword-secrets/](modules/shared/onepassword-secrets/) |
| CI/PR 정책 | `.github/AGENTS.md`, [.github/workflows/](.github/workflows/) |
| 테스트 | [tests/AGENTS.md](tests/AGENTS.md), `make test*` |
| 문서 정책 | [docs/AGENTS.md](docs/AGENTS.md) |

## API / Entry Points

| 영역 / Area | 진입점 / Entry Point |
|---|---|
| 코어 플릿 / Core fleet | `100-pve/terraform/main.tf`, `100-pve/envs/prod/hosts.tf` |
| Tier 1 앱 | `102-traefik/terraform/main.tf`, `105-elk/terraform/main.tf` |
| 외부 제공자 / External providers | `215-synology/main.tf`, `300-cloudflare/terraform/main.tf` |
| 모듈 / Modules | `modules/proxmox/*/main.tf`, `modules/cloudflare/tunnel/main.tf`, `modules/elasticstack/*/main.tf` |
| 도구 / Tooling | `scripts/validate-docs/main.go`, `scripts/audit-workflows.go`, `300-cloudflare/scripts/collect.go` |
| Workers | `300-cloudflare/workers/*/src/index.ts` |

Make 별칭은 워크스페이스의 명령 계약(command contract) 입니다. 예: `make plan SVC=pve`, `make plan SVC=cloudflare`.

## Quickstart

선행 조건: Terraform 1.10.5, `make`, 1Password CLI(비밀 주입 시), Proxmox/Cloudflare/GCP 자격 증명 접근.

```bash
# 1) 저장소 클론
git clone <repo-url> && cd <repo>

# 2) 워크스페이스 초기화 (별칭 또는 풀 경로)
make init SVC=pve          # 100-pve/terraform
make init SVC=cloudflare   # 300-cloudflare/terraform

# 3) 플랜 / 적용
make plan  SVC=pve
make apply SVC=pve

# 4) 전체 워크스페이스 검증
make fmt
make validate
make lint
```

비밀은 `homelab` 1Password 볼트에서 가져오며, `modules/shared/onepassword-secrets/` 모듈이 환경변수로 노출합니다. 자격 증명을 레포지토리에 커밋하지 마세요.

자세한 사용법은 [docs/](docs/) 및 [ARCHITECTURE.md](ARCHITECTURE.md) 를 참고하세요.

## Commands Reference

`Makefile` 은 모든 Terraform 작업을 단일 진입점으로 제공합니다. `SVC`는 워크스페이스 디렉터리 또는 별칭입니다.

| 타겟 / Target | 설명 / Description |
|---|---|
| `make help` | 사용 가능한 타겟과 별칭 출력 |
| `make init SVC=<ws>` | Terraform init (워크스페이스별) |
| `make plan SVC=<ws>` | 플랜 파일 `tfpla` 생성 |
| `make apply SVC=<ws>` | 플랜 적용 |
| `make verify SVC=<ws>` | Terraform verify |
| `make fmt` | 모든 워크스페이스 `*.tf` 포맷팅 (nested 포함) |
| `make validate` | 모든 워크스페이스 validate |
| `make lint` | TFLint 등 lint |
| `make lint-go` | Go 스크립트 lint |
| `make backup` | 상태 백업 |
| `make drift-check` | 실제 상태와 코드 비교 |
| `make test` / `test-unit` / `test-integration` / `test-workspace` | 네이티브 `terraform test` (provider-mocked 기본) |
| `make docs` | 문서 생성/갱신 |
| `make pre-commit-install` / `pre-commit-run` | pre-commit 훅 관리 |
| `make setup` | 로컬 환경 셋업 |

지원 별칭: `jclee pve runner traefik elk mcphub oc synology youtube cloudflare safetywallet gcp`.

## Configuration & Secrets

- **Terraform 버전**: `1.10.5` (제약 `>= 1.7, < 2.0`).
- **백엔드**: 로컬, 워크스페이스 옆. `100-pve/terraform` 및 `105-elk`는 플랜/상태 아티팩트가 명시적 예외로 공존합니다.
- **비밀 소스**: 1Password vault `homelab`. 모듈 [modules/shared/onepassword-secrets/](modules/shared/onepassword-secrets/) 가 lookup 주체입니다.
- **변수/출력 컨벤션**: 모든 `variable`/`output`에 description, `variable`는 타입 명시.
- **네이밍**: Terraform 식별자 `snake_case`, 단일 인스턴스 리소스는 `resource "x" "this"`. 템플릿/스크립트는 `kebab-case`.
- **CI 직렬화**: GitHub Actions 동시성 그룹이 워크스페이스 apply 순서를 직렬화합니다.

## Architecture

| 계층 / Layer | 책임 / Responsibility | 위치 / Location |
|---|---|---|
| Tier 0 | Proxmox 호스트·스토리지·네트워크·VMID SSoT | `100-pve/terraform/`, `100-pve/envs/prod/hosts.tf` |
| Tier 1 | 내부 서비스 (Traefik, CoreDNS, ELK, MCP Hub) | `102-traefik/`, `103-coredns/`, `105-elk/`, `112-mcphub/` |
| Tier 2 | 개인/외부 연동 (Synology, YouTube, Open Cloud, Safety Wallet) | `200-oc/`, `215-synology/`, `220-youtube/`, `310-safetywallet/` |
| External | Cloudflare (DNS/터널/Workers), GCP | `300-cloudflare/`, `400-gcp/` |
| Shared | 재사용 모듈 (Proxmox, Cloudflare, Elastic Stack, 1Password) | `modules/` |
| Tooling | 문서 검증, 워크플로 감사, 템플릿 검증 | `scripts/`, `tests/` |

핵심 흐름:

1. `100-pve/envs/prod/hosts.tf` 가 호스트/IP/VMID SSoT 역할.
2. `100-pve` 가 `templates/*.tftpl` 을 렌더링해 docker-compose / Corefile / filebeat 등을 생성.
3. Tier 1 서비스는 호스트 맵·템플릿 변수만으로 백엔드 IP 를 참조 (직접 IP 하드코딩 금지).
4. Cloudflare Workers/스크립트는 자식 스코프로 분리되어 각각 자체 도구를 가짐.
5. 모든 비밀은 1Password → 환경변수 → Terraform 변수 경로로만 주입.

자세한 내용은 [ARCHITECTURE.md](ARCHITECTURE.md) 와 [DEPENDENCY_MAP.md](DEPENDENCY_MAP.md) 를 참고하세요.

## Local Development & Testing

- **포맷/검증**: `make fmt && make validate && make lint`
- **테스트**: `make test-unit`, `make test-integration`, `make test-workspace`. 기본적으로 provider-mock.
- **pre-commit**: `make pre-commit-install` 후 커밋 시 자동 검사.
- **문서 작업 후**: `make docs` 로 검증. ADRs는 append-only, runbook은 실행 가능 형태로 유지.
- **드리프트 확인**: `make drift-check` 로 실제 인프라와 코드 일치 여부 확인.

테스트 컨벤션은 [tests/AGENTS.md](tests/AGENTS.md) 참고.

## Contribution

기여 전 다음 문서를 읽어 주세요:

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [CODE_STYLE.md](CODE_STYLE.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)
- 각 워크스페이스의 `AGENTS.md` (예: `105-elk/AGENTS.md`, `300-cloudflare/AGENTS.md`)

권장 절차:

1. 이슈 또는 워크스페이스별 `AGENTS.md`에서 작업 범위를 확인합니다.
2. 호스트 변경은 `100-pve/envs/prod/hosts.tf` 부터, 서비스 설정은 `templates/*.tftpl` 부터 수정합니다.
3. `make fmt validate lint` 와 `make test` 를 로컬에서 통과시킵니다.
4. PR 에 변경 의도와 영향 워크스페이스를 명시합니다.

## Maintainers / Contact

| 역할 | 담당 / Owner |
|---|---|
| 저장소 소유 | [OWNERS](OWNERS), [OWNERS_ALIASES](OWNERS_ALIASES) |
| 1Password vault | `homelab` (단일 운영자) |
| CI/CD | GitHub Actions, `.github/workflows/` |

질문·이슈는 GitHub Issues 또는 워크스페이스별 `AGENTS.md` 의 안내를 따릅니다.

## Further Documentation

| 문서 / Document | 경로 / Path |
|---|---|
| 아키텍처 요약 | [ARCHITECTURE.md](ARCHITECTURE.md) |
| 의존성 맵 | [DEPENDENCY_MAP.md](DEPENDENCY_MAP.md) |
| 코드 스타일 | [CODE_STYLE.md](CODE_STYLE.md) |
| 기여 가이드 | [CONTRIBUTING.md](CONTRIBUTING.md) |
| 프로젝트 지식 베이스 | [AGENTS.md](AGENTS.md) |
| 워크스페이스 메모 | `*/AGENTS.md` (예: `105-elk/AGENTS.md`, `300-cloudflare/AGENTS.md`) |
| 테스트 정책 | [tests/AGENTS.md](tests/AGENTS.md) |
| 문서 정책 | [docs/AGENTS.md](docs/AGENTS.md) |
| 라이선스 | [LICENSE](LICENSE) |
| Cloudflare 요구사항 | [300-cloudflare/docs/requirements.md](300-cloudflare/docs/requirements.md) |