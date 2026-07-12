# jclee.me Homelab Infrastructure

[![Terraform](https://img.shields.io/badge/Terraform-1.10.5-7B42BC?logo=terraform&logoColor=white)]()
[![License](https://img.shields.io/badge/license-Proprietary-lightgrey)]()
[![Status](https://img.shields.io/badge/status-Active_Development-blue)]()
[![Domain](https://img.shields.io/badge/domain-jclee.me-0a7)]()

## 한국어 요약

`jclee.me` 홈랩을 위한 인프라-코드(IaC) 저장소입니다. Terraform 1.10.5로 Proxmox 기반
LXC/VM 플릿, 템플릿 렌더링 서비스 구성, Cloudflare 외부 통합을 단일 트리에서 관리합니다.
운영자는 `make <target> SVC=<alias>` 형식으로 워크스페이스를 선택해 plan/apply/lint/validate를
실행하며, 비밀은 1Password vault `homelab`에서만 조회합니다. CI는 GitHub Actions 동시성으로
직렬화되어 안전하게 적용됩니다.

## English Summary

Infrastructure-as-code repository for the `jclee.me` homelab. Terraform 1.10.5 manages a
Proxmox-backed LXC/VM fleet, template-rendered service configs, and Cloudflare edge
integrations from a single tree. Operators select a workspace with `make <target> SVC=<alias>`
to run plan/apply/lint/validate; secrets are pulled only from the 1Password `homelab` vault.
GitHub Actions concurrency serializes production applies.

## 빠른 참조 / Quick Reference

| 영역 / Area | 경로 / Path | 역할 / Role |
|---|---|---|
| Core DNS | `103-coredns/` | split-horizon Corefile 템플릿, docker-compose, filebeat 출력 |
| Log Pipeline | `105-elk/` | ELK 스택 Terraform, logstash/filebeat 템플릿, ILM 스크립트 |
| MCP Hub | `112-mcphub/` | MCP Hub 컨테이너 자산, 1Password Connect 템플릿, SDK 패치 |
| Edge / Workers | `300-cloudflare/` | Cloudflare Terraform, 시크릿 인벤토리, Workers 자산 |
| 빌드 계약 / Build contract | `Makefile`, `build.env` | 워크스페이스 별칭, 환경 변수 주입 |

## 운영자 흐름 / Operator Flow

1. 워크스페이스 선택 — `SVC=elk`, `SVC=mcphub`, `SVC=cloudflare`, `SVC=coredns`.
2. 초기화 — `make init SVC=<workspace>` 로 provider 다운로드.
3. 계획 — `make plan SVC=<workspace>` 로 `tfpla` 산출.
4. 적용 — `make apply SVC=<workspace>` (CI 동시성 직렬화).
5. 검증 — `make lint SVC=<workspace>`, `make validate SVC=<workspace>`.
6. 테스트 — `make test` (네이티브 `terraform test`, provider-mocked).

## 목차 / Contents

- [목적 및 구성 / Purpose & Package Contents](#목적-및-구성--purpose--package-contents)
- [상태 / Status](#상태--status)
- [먼저 읽을 파일 / First Files to Read](#먼저-읽을-파일--first-files-to-read)
- [진입점 / Entry Points](#진입점--entry-points)
- [빠른 시작 / Quickstart](#빠른-시작--quickstart)
- [명령어 / Commands](#명령어--commands)
- [로컬 개발 / Local Development](#로컬-개발--local-development)
- [테스트 / Testing](#testing)
- [기여 / Contribution](#contribution)
- [운영자 / Maintainers](#운영자--maintainers)
- [추가 문서 / Further Documentation](#추가-문서--further-documentation)

## 목적 및 구성 / Purpose & Package Contents

`jclee.me` 홈랩에서 실행되는 서비스를 코드로 선언하기 위한 저장소입니다. Tier 0(Proxmox
호스트), Tier 1(프록시/로그/MCP), 외부(Cloudflare) 자원을 분리된 워크스페이스로 정의하고,
`*.tftpl` 템플릿으로 컨테이너 환경과 filebeat 출력을 중앙에서 렌더링합니다.

| 디렉터리 / Directory | 핵심 자산 / Key Assets | 책임 / Responsibility |
|---|---|---|
| `103-coredns/` | `templates/Corefile.tftpl`, `templates/docker-compose.yml.tftpl`, `templates/filebeat.yml.tftpl` | 내부/외부 도메인 split-horizon DNS, filebeat 출력 |
| `105-elk/` | `terraform/`, `templates/`, `config/`, `scripts/setup-ilm.go`, `scripts/setup-watcher.go`, `scripts/remove-promtail.go` | Elasticsearch + Logstash + Kibana 스택, ILM 정책, 워치독 |
| `112-mcphub/` | `Dockerfile.{dev-browser,playwright,proxmox}`, `mcp_servers.json`, `op-mcp-server/`, `config/entrypoint-patch.go`, `config/patch-sdk-schema.cjs`, `validate_mcps.py` | MCP Hub 컨테이너, 1Password Connect 통합, SDK 스키마 패치 |
| `300-cloudflare/` | `terraform/`, `inventory/secrets.yaml`, `scripts/{audit,collect,deploy-worker,generate-bindings,sync}.go`, `workers/synology-proxy/` | DNS/Workers/Edge 스크립트, 시크릿 인벤토리 감사 |

루트의 `Makefile`은 `pve`, `traefik`, `synology`, `gcp` 등 추가 워크스페이스 별칭을
정의합니다. 이 README는 현재 트리에 노출된 4개 워크스페이스만 상세 기술합니다.

## 상태 / Status

- **런타임 / Runtime**: Active development, 프로덕션 적용 중.
- **Terraform / Version**: 1.10.5 (`>= 1.7, < 2.0`).
- **보안 / Security**: 비밀은 1Password vault `homelab`에서만 조회, 커밋 금지.
- **CI**: GitHub Actions 동시성 직렬화.
- **지원 중단 여부 / Deprecated**: 아니요 / No.

## 먼저 읽을 파일 / First Files to Read

| 문서 / Doc | 읽는 이유 / Why read |
|---|---|
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | 티어, 워크스페이스, 모듈 구조 |
| [`DEPENDENCY_MAP.md`](./DEPENDENCY_MAP.md) | 워크스페이스 간 의존 그래프 |
| [`CODE_STYLE.md`](./CODE_STYLE.md) | Terraform/Go/JS 컨벤션 |
| [`CONTRIBUTING.md`](./CONTRIBUTING.md) | PR 정책, 커밋 메시지 규약 |
| [`AGENTS.md`](./AGENTS.md) (루트) | 저장소 전체 컨벤션과 주의사항 |
| `{workspace}/AGENTS.md` | 워크스페이스별 운영 메모 |
| [`Makefile`](./Makefile) | 빌드/검증 명령 계약 |
| [`build.env`](./build.env) | 환경 변수 주입 규약 |

## 진입점 / Entry Points

- **빌드 계약**: [`Makefile`](./Makefile) — `make help`로 전체 타깃 확인.
- **환경 변수**: [`build.env`](./build.env) — Terraform 실행 시 자동 주입.
- **시크릿 조회**: 1Password Connect SDK, `112-mcphub/op-mcp-server/` Node 어댑터.
- **헬스 체크**: ELK 워치독은 `105-elk/scripts/setup-watcher.go`, Cloudflare 인벤토리 점검이
  `300-cloudflare/scripts/audit.go`.
- **검증 스크립트**: MCP 서버 정합성 — `112-mcphub/validate_mcps.py`.
- **CI 정책**: `.github/workflows/` (많은 워크플로우가 `jclee941/.github`로 위임).

## 빠른 시작 / Quickstart

### 사전 준비 / Prerequisites

| 도구 / Tool | 용도 / Purpose | 권장 버전 / Recommended |
|---|---|---|
| Terraform | IaC 실행 | 1.10.5 |
| Go | 스크립트 빌드 | 1.22+ |
| Node.js | `op-mcp-server`, `patch-*.cjs` | 20+ |
| Python | `validate_mcps.py` | 3.11+ |
| 1Password CLI | 시크릿 조회 | `op` 명령 사용 가능 |
| pre-commit | 훅 실행 | 최신 |

### 실행 예시 / Example

```bash
# 1. 빌드 환경 로드
set -a; source build.env; set +a

# 2. 워크스페이스 초기화
make init SVC=elk

# 3. 계획 작성
make plan SVC=elk

# 4. 적용
make apply SVC=elk

# 5. ELK ILM 정책 적용
go run ./105-elk/scripts/setup-ilm.go

# 6. Cloudflare 인벤토리 감사
go run ./300-cloudflare/scripts/audit.go
```

## 명령어 / Commands

| 타깃 / Target | 용도 / Purpose |
|---|---|
| `make init` | `terraform init` |
| `make plan` | `terraform plan -out=tfpla` |
| `make apply` | `terraform apply tfpla` |
| `make verify` | `terraform verify` |
| `make validate` | 모든 워크스페이스 `terraform validate` |
| `make lint` | 모든 워크스페이스 `tflint` |
| `make fmt` | 모든 워크스페이스 `terraform fmt` |
| `make test` | 네이티브 `terraform test` |
| `make test-unit` | 단위 테스트만 |
| `make test-integration` | 통합 테스트만 |
| `make test-workspace` | 워크스페이스 단위 테스트 |
| `make drift-check` | 실제 상태와 선언 상태 비교 |
| `make backup` | 상태 백업 |
| `make docs` | 문서 생성 |
| `make pre-commit-install` | pre-commit 훅 설치 |
| `make pre-commit-run` | pre-commit 훅 실행 |
| `make help` | 사용 가능한 타깃 목록 |

`SVC` 기본값은 `100-pve`이며, `pve`, `traefik`, `elk`, `mcphub`, `synology`,
`cloudflare`, `gcp`, `safetywallet` 등 별칭으로 대체할 수 있습니다.

## 로컬 개발 / Local Development

- 코드 스타일은 [`CODE_STYLE.md`](./CODE_STYLE.md)를 따릅니다.
- `make fmt` 후 `make lint`가 통과해야 커밋합니다.
- pre-commit 훅 설치: `make pre-commit-install`, 실행: `make pre-commit-run`.
- 시크릿은 절대 커밋하지 않습니다. 1Password 경유만 허용됩니다.
- Terraform 식별자는 `snake_case`, 단일 인스턴스 자원은 `resource "x" "this"` 규약.
- 템플릿/스크립트 파일명은 `kebab-case`, 앱 로직은 `templates/*.tftpl`에만 둡니다.

## Testing

- 네이티브 `terraform test` 프레임워크 사용, provider-mocked가 기본입니다.
- `make test-unit`, `make test-integration`, `make test-workspace`로 분리 실행.
- MCP 서버 정의 정합성은 `python 112-mcphub/validate_mcps.py`로 점검합니다.
- 테스트 상세 동작은 `tests/AGENTS.md`를 참조하세요.

## 기여 / Contribution

- PR 정책은 [`CONTRIBUTING.md`](./CONTRIBUTING.md).
- 코드 소유와 리뷰 권한은 [`OWNERS`](./OWNERS), [`OWNERS_ALIASES`](./OWNERS_ALIASES).
- 새 워크스페이스는 `{NNN}-{svc}/` + `AGENTS.md` 동봉이 필수입니다.
- 변수와 출력에는 `description` 필수, 변수는 `type` 명시 필수.
- 모놀리식 상태 백엔드는 워크스페이스별 로컬 예외만 허용 (예: `100-pve/terraform`,
  `105-elk/terraform`). 일반화하지 마세요.

## 운영자 / Maintainers

- 저장소 소유 그룹: [`OWNERS`](./OWNERS), 별칭: [`OWNERS_ALIASES`](./OWNERS_ALIASES).
- 도메인: `jclee.me`.
- 내부 서브넷: `<homelab-host>/24` (실제 값은 1Password 보관, README에 하드코딩 금지).

## 추가 문서 / Further Documentation

- [`ARCHITECTURE.md`](./ARCHITECTURE.md) — 전체 아키텍처.
- [`DEPENDENCY_MAP.md`](./DEPENDENCY_MAP.md) — 워크스페이스 의존 그래프.
- [`CODE_STYLE.md`](./CODE_STYLE.md) — 언어별 컨벤션.
- [`CONTRIBUTING.md`](./CONTRIBUTING.md) — PR/커밋 정책.
- [`103-coredns/README.md`](./103-coredns/README.md) — CoreDNS 워크스페이스.
- [`105-elk/README.md`](./105-elk/README.md) — ELK 워크스페이스.
- [`105-elk/terraform/README.md`](./105-elk/terraform/README.md) — ELK Terraform 모듈.
- [`112-mcphub/README.md`](./112-mcphub/README.md) — MCP Hub 워크스페이스.
- [`300-cloudflare/README.md`](./300-cloudflare/README.md) — Cloudflare 워크스페이스.
- 워크스페이스별 `AGENTS.md` — 운영 메모 및 주의사항.