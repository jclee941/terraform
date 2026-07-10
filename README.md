# jclee.me Homelab Infrastructure-as-Code

[![Terraform](https://img.shields.io/badge/Terraform-1.10.5-7B42BC?logo=terraform)](https://www.terraform.io)
[![Providers](https://img.shields.io/badge/Providers-Proxmox%20%7C%20Cloudflare%20%7C%20GCP-0F172A)](#진입점--entry-points)
[![Secrets](https://img.shields.io/badge/Secrets-1Password%20`homelab`-1572A3)](#비밀-관리)
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions-2088FF?logo=githubactions)](#기여--contributing)
[![License](https://img.shields.io/badge/License-See%20LICENSE-475569)](./LICENSE)

## 한 줄 요약
Proxmox 호스트(Tier 0), Traefik·ELK·MCP Hub(Tier 1), Cloudflare·GCP(외부)를 Terraform으로 선언적으로 관리하는 홈랩 IaC 저장소입니다. 비밀은 1Password `homelab` 볼트에서만 가져오고, 단일 `Makefile` 진입점이 워크스페이스를 라우팅합니다.

## Status

| 영역 | 상태 | 비고 |
|------|------|------|
| Terraform 버전 | 1.10.5 (`>= 1.7, < 2.0`) | 루트 `Makefile`, `build.env` 기준 |
| CI/CD | GitHub Actions | 동시성(concurrency)으로 직렬화 |
| 비밀 백엔드 | 1Password vault `homelab` | 커밋 금지, 모듈 경유 주입 |
| 가시 워크스페이스 | `coredns`, `elk`, `mcphub`, `cloudflare` | 본 README 범위 |
| 별칭 워크스페이스 | `pve`, `runner`, `traefik`, `synology`, `gcp` 등 | `Makefile` `ALIAS_*` 참조 |
| 도메인 | `jclee.me` | 홈랩 운영 |

## 운영 흐름 한눈에

1. 운영자는 `make help`로 사용 가능한 타깃과 워크스페이스 별칭을 확인합니다.
2. `make init SVC=<name>` → `make plan SVC=<name>`으로 변경 영향을 검토합니다 (`tfpla` 생성).
3. 1Password 자격 증명은 `modules/shared/onepassword-secrets/` 경유로 환경 변수에 주입됩니다.
4. PR 승인 및 CI 통과 후 `make apply SVC=<name>`으로 적용합니다.
5. ELK ILM, Cloudflare 자산 동기화, MCP 서버 검증 등 부가 작업은 각 워크스페이스의 `scripts/`에서 보조 도구로 수행합니다.

## 목차 / Table of Contents

- [개요 / Overview](#개요--overview)
- [패키지 구성 / Package Contents](#패키지-구성--package-contents)
- [먼저 읽을 파일 / First Files to Read](#먼저-읽을-파일--first-files-to-read)
- [진입점 / Entry Points](#진입점--entry-points)
- [빠른 시작 / Quickstart](#빠른-시작--quickstart)
- [명령어 / Commands Reference](#명령어--commands-reference)
- [로컬 개발 / Local Development](#로컬-개발--local-development)
- [테스트 / Testing](#테스트--testing)
- [기여 / Contributing](#기여--contributing)
- [관리자 / Maintainers](#관리자--maintainers)
- [추가 문서 / Further Documentation](#추가-문서--further-documentation)
- [도움말 / Getting Help](#도움말--getting-help)
- [라이선스 / License](#라이선스--license)

---

## 개요 / Overview

`jclee.me` 홈랩의 모든 인프라를 코드로 선언·검증·적용하기 위한 저장소입니다. Proxmox 호스트의 LXC/VM 자원을 단일 출처(SSoT)로 정의하고, Tier 1 서비스(Traefik 리버스 프록시, ELK 로그 스택, MCP Hub)와 외부 통합(Cloudflare DNS·터널·Worker, GCP)을 동일한 워크플로로 다룹니다.

핵심 가치:

- **선언적 IaC** — 자원은 `.tf` + `.tftpl`로만 변경하며 산출물을 직접 편집하지 않습니다.
- **중앙 렌더링** — `100-pve`가 다른 워크스페이스의 템플릿을 모아 호스트 설정으로 변환합니다.
- **비밀 분리** — 자격 증명은 1Password에만 두고 Terraform 변수로는 참조만 합니다.
- **단일 진입점** — 모든 작업은 `make <target> SVC=<workspace>`로 라우팅됩니다.

## 패키지 구성 / Package Contents

본 README는 실제로 보이는 최상위 디렉터리만 반영합니다. `Makefile`의 `ALIAS_*`는 `100-pve`, `101-runner`, `102-traefik`, `215-synology`, `400-gcp` 등 추가 워크스페이스를 가리키지만, 본 뷰에는 포함되지 않습니다. 전체 워크스페이스 목록은 `AGENTS.md`의 `STRUCTURE` 절을 참조하세요.

### 최상위 구조

```text
.
├── AGENTS.md                # 프로젝트 지식 베이스 (구조, 컨벤션, 안티패턴)
├── ARCHITECTURE.md          # 아키텍처 상세 결정
├── CODE_STYLE.md            # Terraform/스크립트 코딩 컨벤션
├── CONTRIBUTING.md          # 기여 절차
├── DEPENDENCY_MAP.md        # 워크스페이스/모듈 의존성 맵
├── LICENSE                  # 라이선스
├── Makefile                 # 단일 진입점 (별칭 → 워크스페이스)
├── OWNERS                   # 리뷰어 지정
├── OWNERS_ALIASES           # 리뷰어 그룹 별칭
├── README.md                # 본 문서
├── build.env                # 빌드 환경 변수 (Terraform 버전 등)
├── 103-coredns/             # CoreDNS 템플릿 (분할 DNS)
├── 105-elk/                 # ELK 스택 (Terraform + 템플릿 + 운영 스크립트)
├── 112-mcphub/              # MCP Hub + 1Password Connect 자산
└── 300-cloudflare/          # Cloudflare 외부 통합 (Terraform + Worker)
```

### 워크스페이스별 구성

| 디렉터리 | 역할 | 핵심 하위 경로 |
|---------|------|---------------|
| `103-coredns/` | CoreDNS 분할 DNS 템플릿 제공 | `templates/Corefile.tftpl`, `docker-compose.yml.tftpl`, `filebeat.yml.tftpl` |
| `105-elk/` | Tier 1 ELK — Terraform + 템플릿 + 운영 스크립트 | `terraform/`, `templates/`, `config/`, `scripts/` |
| `112-mcphub/` | MCP Hub 및 1Password Connect 자산 | `templates/`, `config/`, `op-mcp-server/`, `mcp_servers.json` |
| `300-cloudflare/` | Cloudflare DNS/터널/Worker 통합 | `terraform/`, `scripts/`, `workers/`, `inventory/` |

### 가시 워크스페이스 하이라이트

| 경로 | 내용 |
|------|------|
| `105-elk/scripts/setup-ilm.go` | Elasticsearch ILM 정책 적용 도구 |
| `105-elk/scripts/setup-watcher.go` | Watcher 등록 도구 |
| `105-elk/scripts/remove-promtail.go` | Promtail 제거 스크립트 |
| `112-mcphub/validate_mcps.py` | MCP 서버 설정 검증기 |
| `112-mcphub/op-mcp-server/index.mjs` | 1Password Connect 기반 MCP 서버 |
| `300-cloudflare/scripts/collect.go` | Cloudflare 자산 수집 |
| `300-cloudflare/scripts/audit.go` | Cloudflare 설정 감사 |
| `300-cloudflare/scripts/sync.go` | Cloudflare 자산 동기화 |
| `300-cloudflare/scripts/deploy-worker.go` | Worker 배포 |
| `300-cloudflare/scripts/generate-bindings.go` | Worker 바인딩 생성 |
| `300-cloudflare/workers/synology-proxy/` | Synology 프록시 Worker |

### 공유 자산

| 경로 | 용도 |
|------|------|
| `Makefile` | 워크스페이스 별칭 해석 및 Terraform 타깃 노출 |
| `build.env` | 빌드 환경 변수 (예: Terraform 버전) |
| `OWNERS`, `OWNERS_ALIASES` | 코드 리뷰어 지정 |

## 먼저 읽을 파일 / First Files to Read

운영자와 기여자 모두 다음 순서로 읽는 것을 권장합니다.

1. `Makefile` — 워크스페이스 별칭과 사용 가능한 타깃을 파악합니다.
2. `AGENTS.md` — 저장소 지식 베이스: 구조, 컨벤션, 안티패턴.
3. `ARCHITECTURE.md` — 아키텍처 결정과 데이터 흐름.
4. `DEPENDENCY_MAP.md` — 워크스페이스/모듈 간 의존 관계.
5. 대상 워크스페이스의 `AGENTS.md` (예: `105-elk/AGENTS.md`, `300-cloudflare/AGENTS.md`).
6. 템플릿을 만질 경우 `{NNN}-{svc}/templates/AGENTS.md`의 렌더링 규칙.

## 진입점 / Entry Points

### Make 타깃 (주요)

| 타깃 | 설명 |
|------|------|
| `make help` | 사용 가능한 타깃과 별칭 도움말 출력 |
| `make init SVC=<name>` | 선택한 워크스페이스 Terraform 초기화 |
| `make plan SVC=<name>` | 플랜 생성 (`tfpla`) |
| `make apply SVC=<name>` | 플랜 적용 |
| `make verify SVC=<name>` | 적용 결과 검증 |
| `make fmt` / `make validate` / `make lint` | 포맷·정적 검증·린트 |
| `make drift-check` | 상태 드리프트 진단 |
| `make test` / `test-unit` / `test-integration` / `test-workspace` | `terraform test` 래퍼 |
| `make docs` | 문서 생성/검증 |
| `make setup` | 초기 부트스트랩 |

### 스크립트/도구 진입점

| 진입점 | 용도 |
|--------|------|
| `105-elk/scripts/setup-ilm.go` | ELK ILM 정책 적용 |
| `105-elk/scripts/setup-watcher.go` | Watcher 등록 |
| `112-mcphub/validate_mcps.py` | MCP 서버 설정 검증 |
| `300-cloudflare/scripts/collect.go` | Cloudflare 자산 수집 |
| `300-cloudflare/scripts/sync.go` | Cloudflare 자산 동기화 |
| `300-cloudflare/scripts/audit.go` | Cloudflare 감사 |
| `300-cloudflare/scripts/deploy-worker.go` | Worker 배포 |
| `300-cloudflare/scripts/generate-bindings.go` | Worker 바인딩 생성 |

### 워크스페이스 별칭 (Makefile `ALIAS_*`)

| 별칭 | 해석되는 경로 |
|------|---------------|
| `pve` | `100-pve/terraform` |
| `runner` | `101-runner` |
| `traefik` | `102-traefik/terraform` |
| `elk` | `105-elk/terraform` |
| `mcphub` | `112-mcphub` |
| `synology` | `215-synology` |
| `cloudflare` | `300-cloudflare/terraform` |
| `gcp` | `400-gcp` |
| `jclee` | `80-jclee` |

잘못된 `SVC` 값을 사용하면 `make`는 디렉터리 목록과 사용 가능한 별칭을 출력하고 실패합니다.

## 빠른 시작 / Quickstart

### 사전 요구 사항

- Terraform 1.10.5 (`>= 1.7, < 2.0`)
- 1Password CLI 및 `homelab` 볼트 접근
- 대상 프로바이더 자격 증명 (Proxmox API, Cloudflare API 토큰 등)
- 워커 운영 시 Node.js (Cloudflare Worker 빌드)

### 표준 워크플로

```bash
# 1) 사용 가능한 타깃 확인
make help

# 2) 워크스페이스 초기화
make init  SVC=elk

# 3) 플랜 생성 및 검토
make plan  SVC=elk

# 4) 적용
make apply SVC=elk

# 짧은 별칭 사용
make plan SVC=cloudflare
```

### 첫 PR 전 체크리스트

- [ ] `make fmt` 적용
- [ ] `make validate` 통과
- [ ] `make lint` 통과
- [ ] 비밀값 미포함 확인 (1Password 경유만 사용)
- [ ] `OWNERS` / `OWNERS_ALIASES` 기준 리뷰어 지정
- [ ] 해당 워크스페이스의 `AGENTS.md` 컨벤션 준수

## 명령어 / Commands Reference

`make help`가 단일 진실 공급원입니다. 주요 그룹은 다음과 같습니다.

| 그룹 | 타깃 | 비고 |
|------|------|------|
| Terraform | `init`, `plan`, `apply`, `verify` | 표준 라이프사이클 |
| 코드 품질 | `fmt`, `validate`, `lint`, `lint-go` | 워크스페이스 자동 스캔 |
| 진단 | `drift-check`, `backup` | 상태 진단 및 백업 |
| 테스트 | `test`, `test-unit`, `test-integration`, `test-workspace` | `terraform test` 래퍼 |
| 문서/훅 | `docs`, `pre-commit-install`, `pre-commit-run` | 문서/훅 |
| 부트스트랩 | `setup` | 초기 환경 구성 |

## 로컬 개발 / Local Development

### 디렉터리 규칙

- 대부분의 Terraform 워크스페이스는 `{NNN}-{svc}/terraform/` 하위에 `.tf` 파일을 둡니다.
- `215-synology`는 평면(flat) 레이아웃의 예외입니다.
- 템플릿 산출물은 `100-pve`에서 중앙 렌더링되므로 직접 편집하지 마세요.
- 로컬 상태/플랜 파일은 보통 워크스페이스 옆에 둡니다. `105-elk`와 `100-pve/terraform`만 예외적으로 보관합니다 (복제 금지).

### 비밀 관리

- 비밀은 1Password `homelab` 볼트에서만 가져옵니다.
- `modules/shared/onepassword-secrets/` 모듈이 환경 변수로 주입합니다.
- 저장소에는 비밀을 커밋하지 않습니다.

### 서비스 구성 변경 절차

1. `{NNN}-{svc}/templates/*.tftpl` 파일을 수정합니다.
2. 해당 워크스페이스에서 `make plan SVC=<svc>`로 영향 검토.
3. PR 제출 → 리뷰 → `make apply SVC=<svc>`로 적용.

### 컨벤션 요약

- Terraform 식별자는 `snake_case`, 단일 인스턴스 리소스는 `resource "x" "this"`.
- 변수/출력에는 설명, 변수에는 명시적 타입.
- 템플릿/스크립트는 `kebab-case`.
- 앱 로직은 `templates/*.tftpl`에 둡니다 (cloud-init 인라인 금지).

## 테스트 / Testing

- 기본 테스트는 네이티브 `terraform test`이며 프로바이더 모킹이 기본값입니다.
- `make test`는 부분 집합을 실행합니다.
- 세분화: `make test-unit`, `make test-integration`, `make test-workspace`.
- 자세한 정책은 `tests/AGENTS.md`를 참조하세요 (전체 모노레포 컨텍스트).

## 기여 / Contributing

- 절차는 `CONTRIBUTING.md`를 따릅니다.
- 스타일은 `CODE_STYLE.md`를 따릅니다.
- `AGENTS.md`의 `ANTI-PATTERNS` 절을 반드시 읽어 주세요.
- 리뷰어는 `OWNERS` 및 `OWNERS_ALIASES`로 지정합니다.
- CI는 GitHub Actions 동시성 설정으로 직렬화되며, 자세한 정책은 `.github/AGENTS.md`를 참조하세요.

## 관리자 / Maintainers

- 책임자/팀은 저장소 최상위의 `OWNERS`와 `OWNERS_ALIASES`를 참조하세요.
- 도메인 컨텍스트: `jclee.me` 홈랩.

## 추가 문서 / Further Documentation

| 문서 | 용도 |
|------|------|
| `AGENTS.md` | 프로젝트 지식 베이스 (구조, 컨벤션, 안티패턴) |
| `ARCHITECTURE.md` | 아키텍처 상세 결정 |
| `CODE_STYLE.md` | 코딩 컨벤션 |
| `CONTRIBUTING.md` | 기여 절차 |
| `DEPENDENCY_MAP.md` | 의존성 맵 |
| `{NNN}-{svc}/AGENTS.md` | 워크스페이스별 컨텍스트 |
| `{NNN}-{svc}/templates/AGENTS.md` | 템플릿 작성 규칙 |
| `105-elk/terraform/README.md` | ELK Terraform 모듈 가이드 |
| `300-cloudflare/README.md` | Cloudflare 통합 가이드 |
| `112-mcphub/README.md` | MCP Hub 가이드 |
| `103-coredns/README.md` | CoreDNS 템플릿 가이드 |

## 도움말 / Getting Help

- 일반 운영/사용 질문: GitHub Discussions 또는 Issues.
- 보안 이슈: `OWNERS`에 명시된 책임자에게 직접 연락 (공개 이슈 금지).
- 정책/규칙 해석: `AGENTS.md`와 해당 워크스페이스의 `AGENTS.md`를 우선 참조.

## 라이선스 / License

저장소 최상위의 [`LICENSE`](./LICENSE) 파일을 참조하세요.