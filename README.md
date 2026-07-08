# jclee.me Homelab Infrastructure-as-Code

[![Terraform](https://img.shields.io/badge/Terraform-1.10.5-7B42BC?logo=terraform)]()
[![Workspaces](https://img.shields.io/badge/workspaces-13-blueviolet)]()
[![Secrets](https://img.shields.io/badge/secrets-1Password-orange)]()
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions-2088FF?logo=github-actions)]()
[![License](https://img.shields.io/badge/license-SEE%20LICENSE-blue)]()

**Terraform 모노레포로 `jclee.me` 홈랩 전체를 코드로 정의·운영합니다.** Proxmox 클러스터 위의 LXC/VM 플릿과 Tier 1 서비스(Traefik, CoreDNS, ELK, MCP Hub), 그리고 Cloudflare·GCP 같은 외부 자산을 단일 파이프라인으로 프로비저닝합니다.

*Declarative Terraform monorepo that provisions the entire `jclee.me` homelab — from the Proxmox LXC/VM fleet and Tier 1 services (Traefik, CoreDNS, ELK, MCP Hub) to externally hosted Cloudflare and GCP assets.*

## 상태 / Status at a Glance

| 항목 | 값 |
|---|---|
| 도메인 | `jclee.me` |
| 내부 서브넷 | `<homelab-host>/24` (Tier 0/1) |
| Terraform 버전 | `>= 1.7, < 2.0` (CI pins 1.10.5) |
| 워크스페이스 수 | 13 (`80-jclee` … `400-gcp`) |
| 시크릿 백엔드 | 1Password vault `homelab` |
| CI/CD | GitHub Actions, concurrency 기반 직렬화 |
| 상태 백엔드 | 워크스페이스별 local state |
| 운영자 진입점 | `make help`, `make SVC=<alias> {plan,apply,verify}` |

## 운영 흐름 / Operator Flow

1. **선언** — 호스트·IP·VMID는 `100-pve/envs/prod/hosts.tf`가 SSoT, 서비스 설정은 `{NNN}-{svc}/templates/*.tftpl`.
2. **시크릿** — `modules/shared/onepassword-secrets`가 1Password `homelab` 볼트에서 값을 가져와 환경 변수로 노출.
3. **계획·적용** — `make SVC=<alias> plan` → `make SVC=<alias> apply`로 워크스페이스 단위로 실행.
4. **렌더링** — 템플릿이 워크스페이스 메인에서 중앙 렌더링되어 컨테이너 설정 파일을 생성.
5. **검증** — `make verify`, `make drift-check`, `make lint`가 결과를 보고.
6. **관측** — `105-elk` 스택이 filebeat으로 컨테이너 로그를 수집.

다음 명령으로 시작합니다.

```sh
make help                              # 사용 가능한 타깃 목록
make SVC=pve plan                      # Proxmox 오케스트레이터 플랜
make SVC=traefik apply                 # Traefik 라우트 적용
make SVC=cloudflare plan               # Cloudflare 자산 플랜
make drift-check                       # 전체 드리프트 점검
```

## 목차 / Contents

- [목적 / Purpose](#목적--purpose)
- [저장소 구성 / Package Contents](#저장소-구성--package-contents)
- [먼저 읽을 파일 / First Files to Read](#먼저-읽을-파일--first-files-to-read)
- [진입점 / Entry Points](#진입점--entry-points)
- [빠른 시작 / Quickstart](#빠른-시작--quickstart)
- [Make 명령어 / Make Reference](#make-명령어--make-reference)
- [워크스페이스 인벤토리 / Workspace Inventory](#워크스페이스-인벤토리--workspace-inventory)
- [아키텍처 / Architecture](#아키텍처--architecture)
- [로컬 개발 / Local Development](#로컬-개발--local-development)
- [테스트 / Testing](#테스트--testing)
- [기여 / Contributing](#기여--contributing)
- [유지보수자 / Maintainers](#유지보수자--maintainers)
- [추가 문서 / Further Documentation](#추가-문서--further-documentation)
- [라이선스 / License](#라이선스--license)

## 목적 / Purpose

`jclee.me` 홈랩의 모든 인프라 자산을 Terraform으로 선언적으로 관리하기 위한 단일 진실 공급원(SSOT)입니다. 13개 워크스페이스가 책임 영역을 나누고, `modules/`의 공유 모듈이 Proxmox·Cloudflare·Elastic Stack 자원의 일관된 패턴을 보장합니다.

What this repo is for:

- **Proxmox 플릿** — LXC/VM 추가·리사이즈 (`100-pve/envs/prod/hosts.tf`).
- **Tier 1 서비스** — Traefik 라우트, CoreDNS 스플릿 DNS, ELK 인덱싱, MCP Hub.
- **외부 자산** — Cloudflare DNS·Tunnel·Worker, GCP, SafetyWallet, Synology.
- **보안** — 1Password 시크릿 주입, 시크릿 커밋 금지.
- **자동화** — GitHub Actions로 plan·apply·drift 단위 직렬화.

## 저장소 구성 / Package Contents

번호 규약: 1–255 = 내부 홈랩(`<homelab-host>/24`), 300+ = 외부 자산. 워크스페이스 디렉터리는 `Makefile`의 `ALIAS_*` 맵으로 별칭(`pve`, `elk`, …)을 갖습니다.

| 경로 | 역할 |
|---|---|
| `AGENTS.md` | 프로젝트 지식 베이스 |
| `ARCHITECTURE.md` | 아키텍처 노트 |
| `CODE_STYLE.md` | Terraform·Go 스타일 가이드 |
| `CONTRIBUTING.md` | 기여 절차 |
| `DEPENDENCY_MAP.md` | 모듈·워크스페이스 의존성 |
| `LICENSE` | 라이선스 전문 |
| `Makefile` | 단일 진입 명령 (`SVC=` 별칭) |
| `OWNERS`, `OWNERS_ALIASES` | CODEOWNERS |
| `build.env` | 빌드 환경 변수 |
| `100-pve/` | Tier 0 Proxmox 오케스트레이터, 호스트 SSoT |
| `101-runner/` | GitHub Actions 러너 템플릿 자산 |
| `102-traefik/` | Tier 1 리버스 프록시 |
| `103-coredns/` | CoreDNS 템플릿 자산 |
| `105-elk/` | ELK 스택 + 1Password Connect 자산 |
| `112-mcphub/` | MCP Hub + 1Password Connect 자산 |
| `215-synology/` | Synology 자산 (flat 예외) |
| `300-cloudflare/` | Cloudflare DNS·Tunnel·Worker |
| `310-safetywallet/`, `400-gcp/` | 외부 자산 |
| `80-jclee/`, `200-oc/`, `220-youtube/` | 보조 워크스페이스 |
| `modules/` | 재사용 모듈 (proxmox, shared, cloudflare, elasticstack) |
| `tests/` | Terraform native test |
| `scripts/` | 보조 Go 스크립트 |
| `docs/` | ADR, 런북 |
| `.github/` | 워크플로 + AGENTS.md |

워크스페이스별 세부 구조는 각 폴더의 `AGENTS.md`(`105-elk/AGENTS.md`, `112-mcphub/AGENTS.md`, `300-cloudflare/AGENTS.md` 등)를 참조하세요.

## 먼저 읽을 파일 / First Files to Read

| 작업 | 위치 |
|---|---|
| 호스트·IP·VMID 변경 | `100-pve/terraform/locals.tf`, `100-pve/envs/prod/hosts.tf` |
| 서비스 설정 변경 | `{NNN}-{svc}/templates/*.tftpl` (출력 직접 수정 금지) |
| Traefik 라우트 추가 | `102-traefik/templates/*.yml.tftpl` |
| ELK 파이프라인 | `105-elk/templates/logstash.conf.tftpl`, `modules/elasticstack/` |
| Cloudflare 자산 | `300-cloudflare/terraform/`, `modules/cloudflare/` |
| 시크릿 처리 | `modules/shared/onepassword-secrets/` |
| CI/CD 정책 | `.github/AGENTS.md`, `.github/workflows/` |
| 테스트 동작 | `tests/AGENTS.md` |
| 문서 정책 | `docs/AGENTS.md` |

## 진입점 / Entry Points

| 영역 | 진입점 |
|---|---|
| 코어 플릿 | `100-pve/terraform/main.tf`, `100-pve/envs/prod/hosts.tf` |
| Tier 1 앱 | `102-traefik/terraform/main.tf`, `105-elk/terraform/main.tf` |
| 외부 프로바이더 | `215-synology/main.tf`, `300-cloudflare/terraform/main.tf` |
| 공유 모듈 | `modules/proxmox/*/main.tf`, `modules/cloudflare/tunnel/main.tf`, `modules/elasticstack/*/main.tf` |
| 도구 | `scripts/validate-docs/main.go`, `scripts/audit-workflows.go`, `300-cloudflare/scripts/collect.go` |
| Worker | `300-cloudflare/workers/*/src/index.ts` |
| 빌드 | `Makefile` (`make help`) |
| 자동화 | `.github/workflows/*.yml` |

## 빠른 시작 / Quickstart

사전 요구사항: Terraform `>= 1.7, < 2.0`, `make`, 1Password CLI 인증, GitHub Actions 권한.

```sh
git clone <repo-url> jclee-homelab
cd jclee-homelab

make help                              # 사용 가능한 타깃 목록
make SVC=pve init                      # 워크스페이스 초기화
make SVC=pve plan                      # 플랜 작성
make SVC=pve validate                  # 구성 검증
make SVC=pve lint                      # 린트
make SVC=pve apply                     # 적용
make drift-check                       # 전체 드리프트 점검
```

워크스페이스 별칭: 내부 1–255 그룹은 `jclee`, `pve`, `runner`, `traefik`, `elk`, `mcphub`, `oc`, `synology`, `youtube`. 외부 300+ 그룹은 `cloudflare`, `safetywallet`, `gcp`.

## Make 명령어 / Make Reference

`SVC` 변수로 워크스페이스를 선택합니다. `ALIAS_$(SVC)`가 정의돼 있으면 그 경로를, 아니면 `SVC`를 그대로 사용합니다. `TF_WORKSPACE_DIRS`는 `*.tf`가 있는 모든 워크스