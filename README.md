# jclee.me 홈랩 Terraform 인프라 / jclee.me Homelab Terraform Infrastructure

[![Terraform](https://img.shields.io/badge/Terraform-1.10.5-7B42BC?logo=terraform&logoColor=white)](.)
[![Makefile](https://img.shields.io/badge/Build-Makefile-0277BD?logo=gnu&logoColor=white)](Makefile)
[![Secrets](https://img.shields.io/badge/Secrets-1Password-1572B6)](.)
[![CI](https://img.shields.io/badge/CI-GitHub_Actions-2088FF?logo=github-actions&logoColor=white)](.github/workflows/)
[![Status](https://img.shields.io/badge/Status-Active-brightgreen)](.)
[![License](https://img.shields.io/badge/License-See%20LICENSE-blue)](LICENSE)

## 개요 / Overview

`jclee.me` 홈랩을 코드로 정의하고 유지하기 위한 Terraform 인프라 모음입니다. Proxmox 위의 LXC/VM 플릿, 내부 서비스(Traefik, CoreDNS, ELK, MCP Hub, Synology, YouTube, Open Cloud 등), 그리고 Cloudflare·GCP 같은 외부 서비스를 **번호가 매겨진 워크스페이스** 단위로 프로비저닝합니다. 비밀은 1Password `homelab` 볼트에서 주입하고, 상태는 워크스페이스 옆 로컬에 두며, GitHub Actions 동시성 그룹이 apply 순서를 직렬화합니다. 일부 워크스페이스는 템플릿 전용이며 `100-pve`가 `.tftpl` 파일을 중앙에서 렌더링합니다.

This repository defines and maintains the `jclee.me` homelab as Terraform code. Numbered workspaces provision a Proxmox LXC/VM fleet, internal services (Traefik, CoreDNS, ELK, MCP Hub, Synology, YouTube, Open Cloud), and external providers (Cloudflare, GCP). Secrets are pulled from the 1Password `homelab` vault, state lives beside each workspace, and GitHub Actions concurrency groups serialize apply order. Template-only workspaces have their `.tftpl` files rendered centrally by `100-pve`.

## 한눈에 보기 / At a Glance

| 항목 / Item | 값 / Value |
|---|---|
| 도메인 / Domain | `jclee.me` |
| 사설 LAN / Private LAN | `<homelab-subnet>/24` (RFC1918 자리표시자) |
| Terraform | 1.10.5, 제약 `>= 1.7, < 2.0` |
| 워크스페이스 / Workspaces | NNN-번호 디렉터리, Makefile 별칭 12개 |
| 비밀 / Secrets | 1Password vault `homelab` |
| 상태 백엔드 / State backend | 로컬, 워크스페이스 옆 |
| CI/CD | GitHub Actions, 동시성 그룹 직렬화 |
| 상태 / Status | Active (개인 홈랩) |
| 라이선스 / License | [LICENSE](LICENSE) 참조 |

## 요청 흐름 / Request Flow

1. 운영자가 `100-pve/envs/prod/hosts.tf`(호스트/IP/VMID 단일 진실 공급원) 또는 워크스페이스 `variables.tf`/`main.tf`를 수정합니다.
2. 로컬에서 `make plan SVC=<alias>` 으로 Terraform 플랜을 생성하고 PR을 엽니다.
3. GitHub Actions의 동시성 그룹이 워크스페이스별 apply 순서를 직렬화합니다.
4. 워크스페이스 `terraform/` 내부 `*.tf`가 `modules/shared`、`modules/proxmox`、`modules/cloudflare`、`modules/elasticstack`을 호출합니다.
5. 비밀은 `modules/shared/onepassword-secrets/` 경유로 1Password에서 주입되며 평문 파일은 커밋되지 않습니다.
6. 계획된 변경은 1Password 토큰·Cloudflare API 토큰·Proxmox API 자격증명을 사용해 실제 인프라에 반영됩니다.
7. 로그·메트릭은 1Password Connect, MCP Hub 등의 보조 컨테이너가 ELK 및 파일비트로 전달합니다.

## 목차 / Table of Contents

- [아키텍처 / Architecture](#아키텍처--architecture)
- [워크스페이스 맵 / Workspace Map](#워크스페이스-맵--workspace-map)
- [디렉터리 레이아웃 / Directory Layout](#디렉터리-레이아웃--directory-layout)
- [빠른 시작 / Quick Start](#빠른-시작--quick-start)
- [명령어 레퍼런스 / Command Reference](#명령어-레퍼런스--command-reference)
- [설정과 비밀 / Configuration & Secrets](#설정과-비밀--configuration--secrets)
- [로컬 개발 / Local Development](#로컬-개발--local-development)
- [테스트 / Testing](#테스트--testing)
- [기여 / Contributing](#기여--contributing)
- [유지보수 / Maintainers](#유지보수--maintainers)
- [추가 문서 / Further Documentation](#추가-문서--further-documentation)

## 아키텍처 / Architecture

| 계층 / Tier | 책임 / Responsibility | 대표 워크스페이스 / Representative Workspace |
|---|---|---|
| Tier 0 | Proxmox 플릿 오케스트레이션, 호스트/IP/VMID SSoT | `100-pve` |
| Tier 1 | 내부 서비스 리버스 프록시·로그·검색·MCP | `102-traefik`, `103-coredns`, `105-elk`, `112-mcphub` |
| 외부 / External | 클라우드 제공자, Workers, 외부 API | `200-oc`, `215-synology`, `220-youtube`, `300-cloudflare`, `310-safetywallet`, `400-gcp` |
| 보조 / Side | 템플릿 전용 또는 워크스테이션 골격 | `80-jclee`, `101-runner` |
| 공유 / Shared | 모듈·테스트·문서·자동화·CI 정책 | `modules/`, `tests/`, `scripts/`, `docs/`, `.github/` |

핵심 모듈 진입점은 `modules/proxmox/{lxcm,vm,bootstrap}/main.tf`, `modules/cloudflare/tunnel/main.tf`, `modules/elasticstack/{filebeat,logstash,ilm}/main.tf`, `modules/shared/onepassword-secrets/` 4개 영역에 분포된 10개의 `main.tf` 입니다. 자세한 동작과 데이터 흐름은 [ARCHITECTURE.md](ARCHITECTURE.md)와 [DEPENDENCY_MAP.md](DEPENDENCY_MAP.md)에 정리되어 있습니다.

## 워크스페이스 맵 / Workspace Map

| 별칭 / Alias | 디렉터리 / Directory | 분류 / Category | 비고 / Notes |
|---|---|---|---|
| `jclee` | `80-jclee` | 보조 | 워크스테이션 골격 |
| `pve` | `100-pve/terraform` | Tier 0 | 호스트 SSoT, 템플릿 렌더링 |
| `runner` | `101-runner` | 보조 / 템플릿 전용 | GitHub Actions 러너 |
| `traefik` | `102-traefik/terraform` | Tier 1 | 리버스 프록시 + 라우트 템플릿 |
| `coredns` | `103-coredns` | Tier 1 / 템플릿 전용 | 분할 DNS |
| `elk` | `105-elk/terraform` | Tier 1 | ELK Terraform + 템플릿 + 스크립트 |
| `mcphub` | `112-mcphub` | Tier 1 / 템플릿 전용 | MCP Hub + 1Password Connect |
| `oc` | `200-oc` | 외부 | Open Cloud |
| `synology` | `215-synology` | 외부 | 플랫 레이아웃 예외 |
| `youtube` | `220-youtube` | 외부 |  |
| `cloudflare` | `300-cloudflare/terraform` | 외부 | DNS/터널/Workers + 스크립트 + Workers |
| `safetywallet` | `310-safetywallet` | 외부 |  |
| `gcp` | `400-gcp` | 외부 |  |

> 참고: 위 표의 디렉터리는 [Makefile](Makefile) 별칭 정의(`ALIAS_*`) 및 [AGENTS.md](AGENTS.md)의 “WHERE TO LOOK” 표를 기준으로 구성되었습니다. 일부는 저장소 점검 시점에 비어 있을 수 있으므로 실제 적용 전 디렉터리 존재 여부를 확인하세요.

## 디렉터리 레이아웃 / Directory Layout

저장소 최상위는 다음 항목으로 구성됩니다.

| 경로 / Path | 분류 / Type | 설명 / Purpose |
|---|---|---|
| `AGENTS.md`, `ARCHITECTURE.md`, `CODE_STYLE.md`, `CONTRIBUTING.md`, `DEPENDENCY_MAP.md` | 문서 / Docs | 프로젝트 지식 베이스, 아키텍처, 스타일, 기여, 의존성 |
| `LICENSE` | 라이선스 / License |  |
| `Makefile` | 빌드 / Build | `SVC`/`ALIAS_*` 진입점, `plan`/`apply`/`fmt`/`validate`/`lint`/`test`/`docs` 등 |
| `OWNERS`, `OWNERS_ALIASES` | 거버넌스 / Governance | 리뷰어/승인자 정의 |
| `build.env` | 환경 / Env | 빌드 환경 변수 |
| `README.md` | 문서 / Docs | 본 문서 |
| `103-coredns/`, `105-elk/`, `112-mcphub/`, `300-cloudflare/` | 워크스페이스 / Workspaces | 점검 시점에 최상위 디렉터리가 확인된 워크스페이스 |

각 워크스페이스는 자체적으로 `terraform/`, `templates/`, `scripts/`, `config/` 등을 가지며, `Makefile` 별칭이 `terraform/` 하위 디렉터리로 라우팅합니다.

## 빠른 시작 / Quick Start

사전 준비:

- Terraform 1.10.5(`>= 1.7, < 2.0`) 및 [`tfenv`](https://github.com/tfutils/tfenv) 권장
- 1Password CLI(`op`) 및 `homelab` 볼트 접근 권한
- Proxmox API 토큰, Cloudflare API 토큰, GitHub PAT 등 워크스페이스별 자격증명
- SSH 접근 가능한 홈랩 점프 호스트(선택)

첫 플랜:

```bash
git clone <repo-url> jclee-infra && cd jclee-infra
make init SVC=pve         # 100-pve/terraform 초기화
make plan SVC=pve         # 호스트 변경 검토
make plan SVC=traefik     # 별칭 사용 예시
make plan SVC=elk
```

변경 적용 후 상태는 각 워크스페이스의 `terraform/` 옆 로컬에 저장되며, `105-elk`와 `100-pve/terraform`만 명시적 예외로 추가 산출물(`tfplan` 등)을 보관합니다.

## 명령어 레퍼런스 / Command Reference

| 명령어 / Command | 기본 / Default | 별칭 / Alias | 동작 / Action |
|---|---|---|---|
| `make init SVC=<alias>` | `100-pve` | 모든 별칭 | 선택한 워크스페이스 `terraform init` |
| `make plan SVC=<alias>` | `100-pve` | 모든 별칭 | `terraform plan -out=tfpla` |
| `make apply SVC=<alias>` | `100-pve` | 모든 별칭 | 저장된 플랜 적용 |
| `make verify SVC=<alias>` | `100-pve` | 모든 별칭 | `terraform verify` |
| `make fmt` | (워크스페이스 루트) | — | `*.tf` 보유 디렉터리 일괄 포맷 |
| `make validate` | (워크스페이스 루트) | — | `terraform validate` |
| `make lint` / `make lint-go` | (워크스페이스 루트) | — | 정적 분석 |
| `make drift-check` | — | — | 드리프트 점검 |
| `make test` / `make test-unit` / `make test-integration` / `make test-workspace` | — | — | 네이티브 `terraform test`(프로바이더 모의) |
| `make backup` | — | — | 상태/산출물 백업 |
| `make docs` | — | — | 문서 재생성 |
| `make pre-commit-install` / `make pre-commit-run` | — | — | pre-commit 훅 관리 |

`SVC`는 풀 경로(`100-pve`) 또는 짧은 별칭(`pve`, `elk`, `cloudflare` 등)을 모두 받습니다. 정의되지 않은 값은 디렉터리 존재 여부를 검증한 뒤 사용할 수 있는 별칭 목록을 안내합니다.

## 설정과 비밀 / Configuration & Secrets

- 비밀은 `modules/shared/onepassword-secrets/`를 통해 1Password `homelab` 볼트에서 동적 주입됩니다. **평문 비밀을 저장소에 커밋하지 마세요.**
- 각 워크스페이스의 `variables.tf`는 명시적 `type` + `description`을 가져야 합니다(컨벤션).
- 템플릿 파일은 `{workspace}/templates/*.tftpl`에 보관하며 `100-pve`가 중앙에서 렌더링합니다. 산출물을 직접 편집하지 마세요.
- 로컬 상태는 워크스페이스 옆 `.tfstate`로 저장되며, `105-elk`/`100-pve/terraform`은 플랜 산출물 보관의 명시적 예외입니다.
- 워크스페이스별 환경 변수(`OP_VAULT`, `CLOUDFLARE_API_TOKEN`, `PROXMOX_API_TOKEN`, `GITHUB_TOKEN` 등)는 `build.env`와 CI 비밀에서 관리합니다.

## 로컬 개발 / Local Development

1. 작업할 워크스페이스의 별칭 또는 풀 경로를 결정합니다.
2. 해당 워크스페이스의 `templates/`(해당 시)와 `terraform/`를 검토합니다.
3. `make init SVC=<alias>` → `make plan SVC=<alias>`으로 변경을 검증합니다.
4. `make fmt`, `make validate`, `make lint`를 통과시킨 뒤 PR을 엽니다.
5. CI에서 동시성 그룹이 적용 순서를 직렬화하므로 동일 워크스페이스 동시 머지는 지양합니다.

워크스페이스 레이아웃 규칙:

- 활성 Terraform 워크스페이스는 일반적으로 `{workspace}/terraform/` 아래에 `*.tf`를 둡니다.
- 예외: `215-synology/`는 플랫 구조를 유지합니다.
- 템플릿과 스크립트는 `kebab-case`, Terraform 식별자는 `snake_case`를 사용합니다.
- 단일 인스턴스 리소스는 `resource "x" "this"` 네이밍을 따릅니다.

## 테스트 / Testing

`tests/`는 네이티브 `terraform test` 환경을 제공하며, 기본적으로 프로바이더 호출을 모의(mock)합니다. Make 타겟은 부분 집합을 실행합니다.

```bash
make test-unit             # 빠른 단위 테스트
make test-integration      # 통합 시나리오
make test-workspace SVC=elk
```

워크스페이스 검증은 동시에 `make validate SVC=<alias>` / `make lint`로 보조합니다. 자세한 테스트 정책은 [tests/AGENTS.md](tests/AGENTS.md)에 정리되어 있습니다.

## 기여 / Contributing

- 코드 스타일과 구조 규칙은 [CODE_STYLE.md](CODE_STYLE.md)를 따릅니다.
- 의존성 변경 시 [DEPENDENCY_MAP.md](DEPENDENCY_MAP.md)를 갱신합니다.
- ADR은 [docs/](docs/) 하위에 추가 전용(append-only)으로 작성합니다.
- PR 정책과 자동화 표면은 [.github/](.github/) 의 워크플로와 그 자리의 가이드를 따릅니다.
- 호스트/IP/VMID의 단일 진실 공급원은 `100-pve/envs/prod/hosts.tf`입니다. 다른 위치에서 중복 정의하지 마세요.

## 유지보수 / Maintainers

- 코드 오너십은 [OWNERS](OWNERS) 및 [OWNERS_ALIASES](OWNERS_ALIASES) 파일로 정의됩니다.
- 일상 운영, 온콜, 알림 채널 등 운영 연락처는 각 워크스페이스별 `AGENTS.md` 및 [CONTRIBUTING.md](CONTRIBUTING.md)에 기재합니다.

## 추가 문서 / Further Documentation

| 문서 / Document | 위치 / Location | 내용 / Contents |
|---|---|---|
| 프로젝트 지식 베이스 / Project knowledge base | [AGENTS.md](AGENTS.md) | 구조, 워크스페이스 위치, 컨벤션, 안티패턴 |
| 아키텍처 / Architecture | [ARCHITECTURE.md](ARCHITECTURE.md) | 계층, 데이터 흐름, 모듈 경계 |
| 코드 스타일 / Code style | [CODE_STYLE.md](CODE_STYLE.md) | `snake_case`/`kebab-case` 규칙, 리소스 네이밍 |
| 의존성 맵 / Dependency map | [DEPENDENCY_MAP.md](DEPENDENCY_MAP.md) | 모듈/외부 자원 의존성 |
| 기여 가이드 / Contributing | [CONTRIBUTING.md](CONTRIBUTING.md) | PR 절차, 워크플로 책임 |
| 라이선스 / License | [LICENSE](LICENSE) | 라이선스 전문 |
| 변경 노트·ADR | [docs/](docs/) | 결정 기록, 런북 |
| 테스트 정책 | [tests/](tests/) | 네이티브 테스트 가이드 |
| CI 정책 | [.github/workflows/](.github/workflows/) | 동시성, 배포 자동화 |

## 운영 상태 / Operations Snapshot

| 신호 / Signal | 출처 / Source | 의미 / Meaning |
|---|---|---|
| 워크스페이스 상태(`*.tfstate`) | 워크스페이스 옆 로컬 백엔드 | 마지막 적용 스냅샷 |
| 적용 이력 | GitHub Actions 런 | 동시성 그룹 직렬화 이력 |
| 비밀 사용 | 1Password `homelab` | 모든 비밀은 1Password 경유 |
| 헬스 체크 | 103/105/112/300 워크스페이스의 컨테이너 | 외부 의존은 개별 검증 |

도움을 받을 수 있는 곳:

- 운영 이슈: 해당 워크스페이스의 `AGENTS.md`, 그리고 [CONTRIBUTING.md](CONTRIBUTING.md)
- 메인터이너: [OWNERS](OWNERS), [OWNERS_ALIASES](OWNERS_ALIASES)
- 라이선스/법무: [LICENSE](LICENSE)