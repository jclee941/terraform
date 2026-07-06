# jclee.me 홈랩 IaC

![Terraform 1.10.5](https://img.shields.io/badge/terraform-1.10.5-623CE4) ![상태: 활성](https://img.shields.io/badge/status-active-success) ![워크스페이스 컨벤션 NNN--SVC](https://img.shields.io/badge/convention-NNN--SVC-informational) ![도메인 jclee.me](https://img.shields.io/badge/domain-jclee.me-blue)

## 한 줄 요약

`jclee.me` 홈랩을 코드로 운영하는 Terraform 모노레포입니다. Proxmox 자원, 티어 1 서비스 템플릿, Cloudflare 외부 종속성, 1Password 비밀 백엔드, GitHub Actions CI/CD를 단일 저장소에서 선언적으로 관리합니다.

## English Summary

Terraform-managed homelab IaC monorepo for `jclee.me`, covering Proxmox fleet provisioning, tier‑1 service templates (Traefik, CoreDNS, ELK, MCP Hub), external Cloudflare resources, 1Password-backed secrets, and CI/CD via GitHub Actions.

## 빠른 참조

| 영역 | 값 |
|------|-----|
| 도메인 | `jclee.me` |
| 서브넷 | `<homelab-host>/24` (호스트 의존, 환경별 정의) |
| IaC 도구 | Terraform 1.10.5 (`>= 1.7, < 2.0`) |
| 티어 0 | Proxmox 오케스트레이터 (`100-pve`) |
| 티어 1 | Traefik, CoreDNS, ELK, MCP Hub |
| 외부 | Cloudflare |
| 비밀 백엔드 | 1Password vault `homelab` |
| 모듈 루트 | `modules/{proxmox,shared,cloudflare,elasticstack}` |
| 빌드 진입점 | `Makefile` (`make help`) |
| 언어 | HCL, Go, TypeScript, YAML, Python |

## 운영 흐름

1. 워크스페이스 선택 — `make SVC=<alias>` (예: `pve`, `elk`, `cloudflare`).
2. 초기화 — `make init`(provider, 잠금 파일).
3. 계획 — `make plan`이 `tfpla` 산출, PR 리뷰에 사용.
4. 적용 — `make apply`, CI 동시성으로 직렬화.
5. 검증 — `make verify`, `make lint`, `make validate`, `make drift-check`.
6. 테스트 — `make test` 또는 `make test-unit`/`test-integration`/`test-workspace`.
7. 백업 — `make backup`, 상태/산출물 보존.

## 목차

- [프로젝트 목적 (Purpose)](#프로젝트-목적-purpose)
- [패키지 구성 (Package Contents)](#패키지-구성-package-contents)
- [상태 (Status)](#상태-status)
- [먼저 읽을 파일 (First Files to Read)](#먼저-읽을-파일-first-files-to-read)
- [진입점 (API or Entry Points)](#진입점-api-or-entry-points)
- [빠른 시작 (Quickstart)](#빠른-시작-quickstart)
- [아키텍처 (Architecture)](#아키텍처-architecture)
- [설정 (Configuration)](#설정-configuration)
- [명령 참조 (Commands Reference)](#명령-참조-commands-reference)
- [로컬 개발 (Local Development)](#로컬-개발-local-development)
- [테스트 (Testing)](#테스트-testing)
- [기여 가이드 (Contributing)](#기여-가이드-contributing)
- [유지보수자 및 문의 (Maintainers & Help)](#유지보수자-및-문의-maintainers--help)
- [추가 문서 (Further Documentation)](#추가-문서-further-documentation)
- [라이선스 (License)](#라이선스-license)

## 프로젝트 목적 (Purpose)

`jclee.me` 홈랩은 단일 머신에 종속된 수동 구성이 아니라 **선언적 IaC**로 재현 가능하게 운영하는 것이 목표입니다. 이 저장소는 다음을 제공합니다.

- Proxmox 기반 LXC/VM 자원의 단일 출처(SSoT) — 호스트, IP, VMID 매핑을 코드로 보관.
- Traefik, CoreDNS, ELK, MCP Hub 등 티어 1 서비스의 **템플릿 기반** 구성 산출물.
- Cloudflare DNS/Tunnel/Workers를 위한 외부 IaC.
- 1Password vault `homelab`을 통한 안전한 시크릿 주입.
- GitHub Actions 기반 CI/CD (동시성으로 직렬화).
- 정적 검증, 드리프트 검사, 단위/통합 테스트를 통한 품질 게이트.

### 대상 사용자

- 자가 호스팅 워크플로의 네트워킹/관측/보안 도구를 직접 합성하려는 운영자.
- 작은 규모에서 IaC 모범 사례를 검증하려는 학습자.
- 프로바이더 모킹 기반 native `terraform test`로 안전하게 실험하려는 개발자.

### 이 저장소로 무엇을 할 수 있는가

- 새 LXC/VM 추가와 리사이즈를 코드 변경만으로 처리.
- 템플릿(`*.tftpl`) 편집으로 서비스 구성을 변경, 중앙 렌더러가 산출물 재생성.
- 새 Traefik 라우트를 호스트 맵에서 참조되는 백엔드 IP와 함께 선언.
- ELK 파이프라인과 인덱싱 정책을 코드 리뷰로 발전.
- Cloudflare DNS/Tunnel/Workers 변경을 PR로 추적.
- 비밀을 커밋하지 않고 1Password 단일 보관에서 일관되게 주입.

## 패키지 구성 (Package Contents)

`NNN-SVC` 워크스페이스 컨벤션을 사용하는 IaC 모노레포입니다. 저장소 트리에 직접 존재하는 최상위 워크스페이스는 다음과 같습니다.

| 경로 | 티어 | 역할 |
|------|------|------|
| `103-coredns/` | Tier 1 | CoreDNS 템플릿(`Corefile.tftpl`), Docker Compose, filebeat 설정 |
| `105-elk/` | Tier 1 | ELK Terraform 모듈, 템플릿, 헬퍼 Go 스크립트 |
| `112-mcphub/` | Tier 1 | MCP 허브 컨테이너, 1Password Connect 자산, 템플릿 |
| `300-cloudflare/` | 외부 | Cloudflare Terraform, 비밀 인벤토리, Workers, 운영 스크립트 |

`AGENTS.md`는 전체 지식 베이스로서 추가 워크스페이스(`100-pve`, `102-traefik`, `200-oc`, `215-synology`, `220-youtube`, `310-safetywallet`, `400-gcp` 등)와 모듈 맵을 정의합니다. 본 트리에는 해당 디렉터리가 직접 노출되어 있지 않을 수 있으므로, 인벤토리의 완전한 그림은 `AGENTS.md`의 구조 표를 참조하십시오.

### 최상위 자산

| 경로 | 역할 |
|------|------|
| `AGENTS.md` | 프로젝트 지식 베이스(운영 컨벤션, 모듈 맵) |
| `ARCHITECTURE.md` | 시스템 아키텍처 설명 |
| `CODE_STYLE.md` | 코드 스타일 가이드 |
| `CONTRIBUTING.md` | 기여 절차 |
| `DEPENDENCY_MAP.md` | 외부/내부 의존성 맵 |
| `Makefile` | 통합 빌드 진입점 |
| `build.env` | 빌드 환경 변수(워크스페이스 공통) |
| `OWNERS`, `OWNERS_ALIASES` | 리뷰 권한 매트릭스 |
| `LICENSE` | 라이선스 |

### 워크스페이스 공통 레이아웃

| 하위 디렉터리 | 역할 |
|---------------|------|
| `terraform/` | `*.tf` 정의(일부 워크스페이스는 평면 레이아웃) |
| `templates/` | `*.tftpl` 템플릿과 부속 자산 |
| `config/` | 정적 자산, 추가 구성 |
| `scripts/` | 보조 Go 스크립트 및 셸 헬퍼 |
| `AGENTS.md` | 워크스페이스 지식 베이스(자율 운영 안내) |

### 명명 규칙

| 범위 | 규칙 | 예시 |
|------|------|------|
| 워크스페이스 디렉터리 | `NNN-SVC` (1–255 내부, 300+ 외부) | `100-pve`, `105-elk`, `300-cloudflare` |
| Terraform 식별자 | `snake_case`, 단일 인스턴스는 `resource "x" "this"` | `resource "proxmox_lxc" "this"` |
| 템플릿/스크립트 | `kebab-case` | `setup-ilm.sh.tftpl` |
| 모듈 진입점 | `modules/<provider>/<module>/main.tf` | `modules/cloudflare/tunnel/main.tf` |

## 상태 (Status)

| 항목 | 상태 |
|------|------|
| 운영 환경 | 활성(개인 홈랩) |
| 프로덕션 사용 | 자체 호스팅 워크로드에 사용 중 |
| 프로바이더 잠금 | `versions.tf`에 정의, Terraform 1.10.5 |
| 상태 백엔드 | 로컬 (명시적 예외 외에는 워크스페이스 인접) |
| CI/CD | GitHub Actions, 동시성으로 직렬화 |
| 비밀 관리 | 1Password vault `homelab` |
| 모듈 수 | 10 (`modules/{proxmox,shared,cloudflare,elasticstack}` 아래) |
| 지원 상태 | 자체 사용 — 외부 호환성은 보장하지 않음 |

### 알려진 예외

- `105-elk/terraform/`은 산출물 인접에 상태/플랜 아티팩트를 보관하는 명시적 예외입니다. 패턴으로 복제하지 마십시오.
- AGENTS.md가 언급하는 평면 레이아웃 워크스페이스(예: `215-synology/`)는 `terraform/` 하위 디렉터리 없이 정의됩니다.

## 먼저 읽을 파일 (First Files to Read)

| 순서 | 경로 | 이유 |
|------|------|------|
| 1 | `AGENTS.md` | 전체 지식 베이스, 컨벤션, 안티패턴 |
| 2 | `ARCHITECTURE.md` | 시스템 아키텍처 |
| 3 | `Makefile` | 명령 계약과 별칭 매핑 |
| 4 | `DEPENDENCY_MAP.md` | 외부/내부 의존성 |
| 5 | `CODE_STYLE.md` | 코드 스타일 기준 |
| 6 | `<workspace>/AGENTS.md` | 작업할 워크스페이스의 운영 지침 |

### 운영 작업별 진입점

| 작업 | 위치 |
|------|------|
| LXC/VM 추가/리사이즈 | `100-pve/terraform/locals.tf` + `100-pve/envs/prod/hosts.tf`(호스트/IP/VMID SSoT) |
| 서비스 구성 변경 | `<workspace>/templates/*.tftpl`(출력물 직접 수정 금지) |
| 새 Traefik 라우트 | `102-traefik/templates/*.yml.tftpl`(백엔드 IP는 호스트 맵에서만) |
| ELK 파이프라인 | `105-elk/templates/logstash.conf.tftpl` + `modules/elasticstack/` |
| Cloudflare DNS/터널/Workers | `300-cloudflare/terraform/` + `modules/cloudflare/` |
| 비밀 검색 | `modules/shared/onepassword-secrets/`(1Password 참조만) |
| CI/CD 정책 | `.github/AGENTS.md` + `.github/workflows/` |
| 테스트 정책 | `tests/AGENTS.md` |
| 문서 정책 | `docs/AGENTS.md`(ADRs은 추가 전용) |

## 진입점 (API or Entry Points)

사람이 호출하는 IaC 시스템이므로 "진입점"은 모듈/Terraform 루트와 Make 타깃입니다.

### Terraform 모듈

| 경로 | 용도 |
|------|------|
| `modules/proxmox/*/main.tf` | LXC/VM 프로비저닝 |
| `modules/cloudflare/tunnel/main.tf` | Cloudflare 터널 |
| `modules/elasticstack/*/main.tf` | ELK 스택 |
| `modules/shared/onepassword-secrets/` | 1Password 백엔드 시크릿 |

### 워크스페이스 진입점

| 경로 | 진입점 |
|------|--------|
| `103-coredns/` | `templates/Corefile.tftpl`, `templates/docker-compose.yml.tftpl`, `templates/filebeat.yml.tftpl` |
| `105-elk/terraform/` | `main.tf`, `providers.tf`, `variables.tf`, `outputs.tf`, `onepassword.tf`, `checks.tf`, `validation.tf`, `versions.tf` |
| `105-elk/config/` | 정적 구성 — `Dockerfile.logstash`, `logstash.conf`, `logstash.yml`, `filebeat.yml`, `ilm-policy.json` |
| `105-elk/scripts/` | `setup-ilm.go`, `setup-watcher.go`, `remove-promtail.go`, 셸 헬퍼 `remove-promtail` |
| `112-mcphub/` | `mcp_servers.json`, `validate_mcps.py`, `op-mcp-server/index.mjs`, Dockerfile 모음 |
| `112-mcphub/config/` | `entrypoint-patch.go`, `patch-sdk-schema.cjs`, `patch-placeholder.cjs`, `filebeat.yml` |
| `300-cloudflare/terraform/` | `main.tf`, `checks.tf`, `validation.tf`, `onepassword.tf`, `outputs.tf`, `providers.tf`, `variables.tf`, `versions.tf` |
| `300-cloudflare/scripts/` | `audit.go`, `collect.go`, `deploy-worker.go`, `generate-bindings.go`, `sync.go` |
| `300-cloudflare/workers/synology-proxy/` | Synology 프록시 Worker |

## 빠른 시작 (Quickstart)

### 사전 요구 사항

| 항목 | 권장 버전 |
|------|-----------|
| Terraform | 1.10.5 (제약: `>= 1.7, < 2.0`) |
| Go | 워크스페이스 헬퍼 스크립트 빌드용 |
| Node.js | Workers 및 일부 헬퍼 스크립트용 |
| Docker / Docker Compose | 템플릿 산출물 검증용 |
| 1Password CLI | 비밀 주입용 |

### 단계별 절차

1. 저장소 클론.

   ```bash
   git clone https://github.com/<owner>/<repo>.git
   cd <repo>
   ```

2. 빌드 환경 적용.

   ```bash
   set -a; source build.env; set +a
   ```

3. 사용 가능한 타깃과 별칭 확인.

   ```bash
   make help
   ```

4. 워크스페이스 선택 및 초기화(`pve` 별칭 예시).

   ```bash
   make SVC=pve init
   ```

5. 계획 검토.

   ```bash
   make SVC=pve plan   # tfpla 산출
   ```

6. 적용.

   ```bash
   make SVC=pve apply
   ```

7. 검증과 드리프트 검사.

   ```bash
   make SVC=pve verify
   make SVC=pve lint
   make SVC=pve validate
   make SVC=pve drift-check
   ```

워크스페이스별 절차 차이는 해당 워크스페이스의 `AGENTS.md`와 `README.md`(`105-elk/terraform/README.md`, `300-cloudflare/README.md` 등)를 참조하십시오.

## 아키텍처 (Architecture)

홈랩은 **세 개의 운영 티어**와 **외부** 범주로 나뉘며, 각 티어는 Make 별칭과 Terraform 루트로 일대일 대응합니다.

### 계층별 책임

| 티어 | 책임 | 예시 |
|------|------|------|
| Tier 0 | 오케스트레이션 호스트 SSoT | `100-pve` (Proxmox 오케스트레이터) |
| Tier 1 | 내부 서비스 | Traefik, CoreDNS, ELK, MCP Hub |
| 외부 | 클라우드/외부 종속성 | Cloudflare (`300-cloudflare`) |

### Terraform 적용 흐름

1. 운영자가 `make SVC=<alias> ...`을 호출.
2. Make가 `ALIAS_*` 테이블로 별칭을 디렉터리 경로로 해소.
3. `init`이 provider 다운로드와 잠금 파일 생성.
4. `plan`이 `tfpla`를 직렬화, CI/PR 리뷰 입력으로 사용.
5. `apply`가 상태 파일 업데이트, GitHub Actions 동시성으로 직렬화.
6. `verify`/`validate`/`fmt`/`lint`/`drift-check`/`test`가 품질 게이트 역할.
7. `backup`이 상태/산출물 보존.

### 비밀 흐름

1. 1Password vault `homelab`에 시크릿 보관.
2. Terraform이 `modules/shared/onepassword-secrets/`로 값을 조회.
3. 환경 변수 또는 모듈 입력으로 주입 — 시크릿은 커밋하지 않음.

### 모듈 계층

| 모듈군 | 역할 | 진입점 |
|--------|------|--------|
| `modules/proxmox` | LXC/VM 프로비저닝 | 각 모듈 `main.tf` |
| `modules/cloudflare` | DNS/Tunnel/접근 | `modules/cloudflare/tunnel/main.tf` |
| `modules/elasticstack` | ELK 스택 | 각 모듈 `main.tf` |
| `modules/shared` | 공통(예: 시크릿) | `modules/shared/onepassword-secrets/` |

상세 시스템 다이어그램과 데이터 흐름은 `ARCHITECTURE.md` 및 `docs/`를 참조하십시오.

## 설정 (Configuration)

다음 규칙이 설정 정합성을 보장합니다.

| 항목 | 규칙 |
|------|------|
| `variable` | 명시적 `type`과 `description` 필수 |
| `output` | `description` 필수 |
| 단일 인스턴스 리소스 | `resource "<type>" "this"` |
| 비밀 | 절대 커밋 금지 — 1Password 참조만 사용 |
| 상태 백엔드 | 로컬이 기본, 예외는 `versions.tf`/워크스페이스 문서에 명시 |
| 빌드 환경 | `build.env`를 공통 베이스로 적용 |

## 명령 참조 (Commands Reference)

`Makefile`이 단일 진입점이며 모든 타깃은 `SVC` 파라미터를 받거나 독립적으로 동작합니다.

| 타깃 | SVC 지원 | 설명 |
|------|---------|------|
| `make help` | – | 사용 가능한 타깃/별칭 출력 |
| `make init` | ✓ | Terraform 초기화 |
| `make plan` | ✓ | `tfpla`로 차이점 직렬화 |
| `make apply` | ✓ | 계획 적용 |
| `make verify` | ✓ | 외부 검증 |
| `make validate` | ✓ | Terraform 문법 검증 |
| `make fmt` | ✓ | `*.tf` 포맷(워크스페이스 전체) |
| `make lint` | ✓ | HCL 정적 분석 |
| `make lint-go` | ✓ | Go 헬퍼 린트 |
| `make drift-check` | ✓ | 상태 드리프트 검사 |
| `make test` | ✓ | Terraform 테스트 |
| `make test-unit` | – | 단위 테스트 |
| `make test-integration` | – | 통합 테스트 |
| `make test-workspace` | – | 특정 워크스페이스 테스트 |
| `make backup` | – | 상태/산출물 백업 |
| `make docs` | – | 문서 생성/검증 |
| `make pre-commit-install` | – | pre-commit 훅 설치 |
| `make pre-commit-run` | – | pre-commit 훅 수동 실행 |
| `make setup` | – | 로컬 1회 셋업 |

### 주요 별칭 매핑

| 별칭 | 디렉터리 |
|------|----------|
| `pve` | `100-pve/terraform` |
| `runner` | `101-runner` |
| `traefik` | `102-traefik/terraform` |
| `coredns` | `103-coredns` |
| `elk` | `105-elk/terraform` |
| `mcphub` | `112-mcphub` |
| `synology` | `215-synology` |
| `cloudflare` | `300-cloudflare/terraform` |
| `safetywallet` | `310-safetywallet` |
| `gcp` | `400-gcp` |

전체 매핑과 디렉터리 검증 로직은 `Makefile`의 `ALIAS_*` 블록과 `check_svc_dir` 매크로를 참조하십시오.

## 로컬 개발 (Local Development)

### 권장 워크플로

1. 베이스라인 확보 — 변경 전 `make SVC=<svc> plan`.
2. 코드 편집 — `templates/*.tftpl`, `terraform/*.tf`, 또는 워크스페이스 스크립트.
3. 포맷과 검증 — `make fmt validate`.
4. 정적 분석 — `make lint lint-go`.
5. 테스트 — `make test test-unit`(해당 시 `test-integration`).
6. 계획 재검토 — `make SVC=<svc> plan`을 다시 실행, `tfpla`를 PR 첨부.
7. pre-commit — `make pre-commit-run`.

### 도구 추천

| 목적 | 도구 |
|------|------|
| 편집기 | VSCode + HashiCorp Terraform 확장 |
| 비밀 접근 | 1Password CLI (`op`) |
| 컨테이너 검증 | Docker Compose (`<workspace>/templates` 렌더 결과) |
| 워커 검증 | Node.js + Wrangler (`300-cloudflare/workers/*`) |

## 테스트 (Testing)

테스트는 기본적으로 프로바이더를 모킹한 native `terraform test`를 사용합니다.

| Make 타깃 | 범위 |
|-----------|------|
| `make test` | Terraform 전체 |
| `make test-unit` | 단위 테스트 |
| `make test-integration` | 통합 테스트 |
| `make test-workspace` | 특정 워크스페이스 |
| `make lint` | HCL 정적 분석 |
| `make validate` | Terraform 문법 검증 |
| `make drift-check` | 상태 드리프트 검사 |

상세 테스트 정책과 모킹 전략은 `tests/AGENTS.md`를 참조하십시오.

## 기여 가이드 (Contributing)

기여 절차는 `CONTRIBUTING.md`를 따릅니다.

- 모든 변경은 PR로 제출.
- 코딩 스타일은 `CODE_STYLE.md` 준수.
- 리뷰 권한 그룹은 `OWNERS`/`OWNERS_ALIASES`에 정의.
- CI는 동시성으로 직렬화되므로 충돌은 PR 순서로 해결.
- 워크스페이스별 추가 지침은 해당 `AGENTS.md`를 참조.

PR 체크리스트:

- [ ] `make fmt validate lint` 통과.
- [ ] `make test` (또는 해당 범위 테스트) 통과.
- [ ] 비밀/내부 IP/개인 정보 미포함.
- [ ] 출력 산출물 직접 변경이 아닌 템플릿/`*.tf` 변경.
- [ ] 관련 `AGENTS.md`/`README.md` 갱신.

## 유지보수자 및 문의 (Maintainers & Help)

리뷰 권한 그룹은 `OWNERS`와 `OWNERS_ALIASES`에 정의되어 있습니다. 질문, 버그, 기능 요청은 저장소 이슈 트래커를 사용하십시오. 본 프로젝트는 개인 홈랩 용도이며 외부 지원 채널은 제공되지 않습니다.

## 추가 문서 (Further Documentation)

| 문서 | 내용 |
|------|------|
| `AGENTS.md` | 프로젝트 지식 베이스, 컨벤션, 안티패턴 |
| `ARCHITECTURE.md` | 시스템 아키텍처 |
| `CODE_STYLE.md` | 코드 스타일 |
| `CONTRIBUTING.md` | 기여 절차 |
| `DEPENDENCY_MAP.md` | 의존성 맵 |
| `<workspace>/AGENTS.md` | 워크스페이스별 운영 지침 |
| `tests/AGENTS.md` | 테스트 정책 |
| `docs/AGENTS.md` | 문서 정책 (ADRs 추가 전용, runbook 실행 가능) |
| `105-elk/terraform/README.md` | ELK 워크스페이스 가이드 |
| `300-cloudflare/README.md` | Cloudflare 워크스페이스 가이드 |
| `300-cloudflare/docs/requirements.md` | Cloudflare 인수 조건 |

## 라이선스 (License)

`LICENSE` 파일을 참조하십시오.