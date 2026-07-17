markdown
# jclee.me Homelab Infrastructure as Code

Terraform 으로 Proxmox 플릿, 리버스 프록시, ELK, MCP Hub, Cloudflare External 자산을 코드로 관리하는 홈랩 인프라 워크스페이스.

A Terraform workspace that codifies the `jclee.me` homelab: Proxmox fleet, reverse-proxy routing, observability, MCP services, and Cloudflare integrations.

![Terraform](https://img.shields.io/badge/terraform-1.10.5-7B42BC?logo=terraform)
![Go](https://img.shields.io/badge/scripts-Go-00ADD8?logo=go)
![Status](https://img.shields.io/badge/status-active-success)
![Secrets](https://img.shields.io/badge/secrets-1Password-0572EC)
![CI](https://img.shields.io/badge/CI-GitHub_Actions-2088FF?logo=githubactions)

## 한눈에 보기

| 항목 | 값 |
| --- | --- |
| 도메인 | `jclee.me` |
| Terraform 버전 | `>= 1.7, < 2.0` (개발 시 1.10.5) |
| 비밀 백엔드 | 1Password vault `homelab` |
| 워크스페이스 규약 | 평면 `NNN-svc` (예: `100-pve`, `105-elk`) |
| 번호 구간 | `1–255` 내부 인프라 / `300+` 외부 클라우드 |
| 명령 진입점 | `Makefile` 별칭 (`pve`, `traefik`, `elk` …) |
| 모듈 루트 | `modules/{proxmox,shared,cloudflare,elasticstack}` |
| 테스트 | 네이티브 `terraform test`, 프로바이더 모의 기본 |
| CI/CD | GitHub Actions, 동시성 직렬화 사용 |
| 사용 중단 영역 | 없음 |

## 운영 흐름 요약

1. `make help` 로 사용 가능한 명령과 별칭 확인
2. `make init SVC=<별칭>` 으로 대상 워크스페이스 초기화
3. `100-pve/envs/prod/hosts.tf` 가 호스트/IP/VMID 의 단일 진실 공급원(SSoT)
4. `make plan SVC=<별칭>` 으로 변경 검토, `make apply SVC=<별칭>` 으로 적용
5. 템플릿(`*.tftpl`)은 `100-pve` 가 중앙 렌더링, 출력 파일 직접 수정 금지
6. 비밀값은 1Password 경유, `modules/shared/onepassword-secrets/` 모듈 사용

> 운영자는 `Makefile` 의 `SVC` 변수와 짧은 별칭만 알면 된다.

## 목차

- [목적](#목적)
- [패키지 내용](#패키지-내용)
- [처음 읽을 파일](#처음-읽을-파일)
- [진입점](#진입점)
- [빠른 시작](#빠른-시작)
- [명령 참조](#명령-참조)
- [로컬 개발](#로컬-개발)
- [테스트](#테스트)
- [기여](#기여)
- [운영 및 연락처](#운영-및-연락처)
- [추가 문서](#추가-문서)

## 목적

`jclee.me` 홈랩을 재현 가능하고 감사 가능한 형태로 운영하기 위한 IaC 저장소다.
Proxmox LXC/VM 플릿, Traefik 라우팅, ELK 로그 파이프라인, MCP Hub, Cloudflare External 자산을
단일 명령 진입점과 단일 비밀 백엔드로 통합한다.

**대상 사용자**

- 홈랩 운영자 — VM/LXC, 라우트, 시크릿 추가를 코드 변경으로 수행
- 자동화 통합 개발자 — GitHub Actions 러너, MCP 서버, Workers 모듈화
- 감사/검토자 — 호스트 SSoT 와 PR 단위 plan 으로 변경 이력 추적

## 패키지 내용

### 최상위 메타파일

| 경로 | 역할 |
| --- | --- |
| `Makefile` | `SVC=` 별칭 기반 모든 Terraform 명령 진입점 |
| `AGENTS.md` | 프로젝트 지식 베이스, 구조, 규약, 안티패턴 |
| `ARCHITECTURE.md` | 계층(Tier 0/1/2) 및 데이터 흐름 명세 |
| `CODE_STYLE.md` | Terraform/Go/템플릿 스타일 규약 |
| `CONTRIBUTING.md` | PR 정책, 워크플로, ADR 절차 |
| `DEPENDENCY_MAP.md` | 모듈/워크스페이스 의존 관계 |
| `LICENSE` | 라이선스 전문 |
| `OWNERS`, `OWNERS_ALIASES` | 리뷰어 책임 매트릭스 |
| `build.env` | 빌드 환경 변수 |

### 워크스페이스

이 저장소는 평면 `NNN-svc` 디렉터리 규약을 따른다.
전체 워크스페이스 인벤토리는 `AGENTS.md` 가 권위 있는 출처다.
아래는 이 스냅샷에서 직접 확인된 워크스페이스다.

| 경로 | 종류 | 비고 |
| --- | --- | --- |
| `103-coredns/` | 활성 | 템플릿 전용 분할 DNS (`Corefile`, docker-compose, filebeat) |
| `105-elk/` | 활성 | Tier 1 ELK (Terraform, 템플릿, `scripts/*.go`, `config/`) |
| `112-mcphub/` | 활성 | MCP Hub 템플릿, 1Password Connect 자산, Docker 빌드 파일 |
| `300-cloudflare/` | 활성 | Cloudflare 독립 Terraform, 시크릿 인벤토리, Workers |

`AGENTS.md` 는 `80-jclee`, `100-pve`, `101-runner`, `102-traefik`,
`200-oc`, `215-synology`, `220-youtube`, `310-safetywallet`, `400-gcp`,
그리고 `modules/`, `tests/`, `scripts/`, `docs/`, `.github/` 를 추가 자원으로 명시한다.
해당 디렉터리의 존재/세부 구조는 저장소 트리와 `AGENTS.md` 의 최신판을 함께 확인한다.

## 처음 읽을 파일

운영자/기여자가 가장 먼저 봐야 할 파일이다.

| 순서 | 파일 | 이유 |
| --- | --- | --- |
| 1 | `README.md` (이 문서) | 개요, 명령 진입점, 구조 |
| 2 | `AGENTS.md` | 프로젝트 지식 베이스, 규약, 안티패턴 |
| 3 | `ARCHITECTURE.md` | 계층, 데이터 흐름, 모듈 경계 |
| 4 | `100-pve/envs/prod/hosts.tf` | 호스트/IP/VMID 의 SSoT (워크스페이스 존재 시) |
| 5 | `Makefile` | 명령 진입점과 별칭 |
| 6 | `DEPENDENCY_MAP.md` | 워크스페이스 간 의존 관계 |
| 7 | `CODE_STYLE.md` | Terraform/템플릿 스타일 규약 |
| 8 | `CONTRIBUTING.md` | PR 절차 및 ADR 정책 |

## 진입점

| 진입점 종류 | 위치 | 용도 |
| --- | --- | --- |
| 메인 명령 | `Makefile` | `init`, `plan`, `apply`, `fmt`, `validate`, `test` |
| 호스트 정의 | `100-pve/envs/prod/hosts.tf` | 호스트, IP, VMID 의 SSoT |
| Proxmox 루트 | `100-pve/terraform/main.tf` | Proxmox 자원 정의 |
| 라우트 추가 | `102-traefik/templates/*.yml.tftpl` | Traefik 백엔드/라우트 |
| 로그 파이프라인 | `105-elk/templates/logstash.conf.tftpl` | ELK 인덱싱/필터 |
| ELK 보조 스크립트 | `105-elk/scripts/*.go` | ILM 설정, 워처, 정리 도구 |
| MCP Hub | `112-mcphub/validate_mcps.py`, `112-mcphub/templates/` | MCP 서버 검증 및 템플릿 |
| Cloudflare 루트 | `300-cloudflare/terraform/main.tf` | DNS, 터널, Workers |
| Cloudflare 감사 | `300-cloudflare/scripts/audit.go`, `collect.go` | DNS/자원 감사 |
| Workers 소스 | `300-cloudflare/workers/*/src/index.ts` | Cloudflare Workers 코드 |
| 비밀 통합 | `modules/shared/onepassword-secrets/` | 1Password Terraform 모듈 |

## 빠른 시작

### 사전 요구 사항

- Terraform `>= 1.7, < 2.0` (개발 시 1.10.5)
- `make`, `git`, `go` (스크립트 사용 시)
- 1Password CLI 및 vault `homelab` 접근 권한
- Proxmox API 토큰 (시크릿으로 주입)
- Cloudflare API 토큰 (`300-cloudflare` 작업 시)

### 첫 워크플로

```bash
# 저장소 클론 후 사용 가능한 명령 확인
make help

# Proxmox 오케스트레이터 초기화 (별칭은 Makefile 이 자동 해석)
make init SVC=pve

# 계획 검토
make plan SVC=pve

# 적용
make apply SVC=pve
```

별칭은 Makefile 의 `ALIAS_*` 매핑으로 실제 경로
(`100-pve/terraform`, `105-elk/terraform` 등) 로 자동 변환된다.
전체 경로(`100-pve`)와 짧은 별칭(`pve`) 둘 다 허용한다.
존재하지 않는 워크스페이스는 친절한 오류 메시지와 사용 가능한 목록을 출력한다.

## 명령 참조

### 사용 가능한 별칭

`Makefile` 에 정의된 워크스페이스 별칭 전체 목록이다.
대상 디렉터리가 이 스냅샷에 없으면 `AGENTS.md` 와 저장소 트리로 확인한다.

| 별칭 | 경로 | 대상 워크스페이스 |
| --- | --- | --- |
| `jclee` | `80-jclee` | 개인 워크스테이션 골격 |
| `pve` | `100-pve/terraform` | Proxmox 오케스트레이터 |
| `runner` | `101-runner` | GitHub Actions 러너 템플릿 |
| `traefik` | `102-traefik/terraform` | 리버스 프록시 |
| `elk` | `105-elk/terraform` | ELK 스택 |
| `mcphub` | `112-mcphub` | MCP Hub |
| `oc` | `200-oc` | 기타 워크스페이스 |
| `synology` | `215-synology` | Synology 통합 (평면 구조) |
| `youtube` | `220-youtube` | YouTube 자동화 |
| `cloudflare` | `300-cloudflare/terraform` | Cloudflare External |
| `safetywallet` | `310-safetywallet` | Safetywallet 통합 |
| `gcp` | `400-gcp` | GCP 통합 |

### 자주 쓰는 명령

| 명령 | 용도 |
| --- | --- |
| `make help` | 사용 가능한 타깃과 별칭 출력 |
| `make init SVC=<별칭>` | 워크스페이스 초기화 |
| `make plan SVC=<별칭>` | 변경 계획 (`tfpla` 출력) |
| `make apply SVC=<별칭>` | 변경 적용 |
| `make verify` | 검증 일괄 실행 |
| `make fmt` | 모든 워크스페이스 포맷 (`tests/`, `modules/` 제외) |
| `make validate` | 모든 워크스페이스 검증 |
| `make lint` | Go/Terraform 린트 |
| `make lint-go` | Go 전용 린트 |
| `make test` | 네이티브 `terraform test` 전체 |
| `make test-unit` | 단위 테스트 |
| `make test-integration` | 통합 테스트 |
| `make test-workspace` | 단일 워크스페이스 테스트 |
| `make drift-check` | 실제 상태와 코드 차이 점검 |
| `make backup` | 상태 백업 |
| `make docs` | 문서 빌드/검증 |
| `make pre-commit-install` | pre-commit 훅 설치 |
| `make pre-commit-run` | pre-commit 훅 실행 |
| `make setup` | 초기 환경 설정 |

`SVC` 가 지정되지 않으면 기본값 `100-pve` 로 동작한다.

## 로컬 개발

### 워크플로

1. 기능별 브랜치 생성 (`feature/<short-desc>`)
2. `Makefile` 의 `SVC` 별칭으로 대상 워크스페이스 선택
3. 호스트 변경이 필요하면 `100-pve/envs/prod/hosts.tf` 만 수정 (SSoT)
4. 서비스 설정 변경은 `templates/*.tftpl` 만 수정 (출력 직접 수정 금지)
5. `make plan SVC=<별칭>` 으로 검토
6. PR 생성, `OWNERS` 매트릭스에 따라 리뷰어 자동 할당
7. CI 동시성 직렬화로 머지 순서 보장
8. 머지 후 `make backup` 으로 상태 백업 확인

### 비밀값 관리

비밀값은 절대 평문으로 커밋하지 않는다.
`modules/shared/onepassword-secrets/` 모듈을 통해 vault `homelab` 에서 주입받는다.
일부 환경 변수로도 주입되며 빌드 컨텍스트는 `build.env` 에 정의한다.

### 코딩 규약 요약

- Terraform 식별자 — `snake_case`
- 단일 인스턴스 자원 — `resource "x" "this"`
- 템플릿/스크립트 파일 — `kebab-case`
- 변수와 출력 — 설명 필수, 변수는 명시적 타입
- 인라인 cloud-init 작성 금지, 앱 로직은 `templates/*.tftpl` 에
- 상태 파일은 워크스페이스 옆에 둠 (`105-elk`, `100-pve/terraform` 은 명시적 예외)
- ADRs 는 추가 전용(append-only)

전체 규약과 안티패턴은 `CODE_STYLE.md`, `AGENTS.md` 참조.

## 테스트

| 명령 | 범위 |
| --- | --- |
| `make test` | 전체 워크스페이스 단위 테스트 |
| `make test-unit` | 단위 테스트만 |
| `make test-integration` | 통합 테스트 |
| `make test-workspace` | 단일 워크스페이스 테스트 |
| `make validate` | 모든 워크스페이스 `terraform validate` |
| `make drift-check` | 실제 상태와 코드 차이 점검 |
| `make lint` | 정적 분석 (Go + Terraform) |

테스트는 기본적으로 프로바이더 모의(mock) 를 사용하므로
Proxmox/Cloudflare 자격 증명 없이 실행 가능하다.
자세한 테스트 정책은 `tests/AGENTS.md` 참조.

## 기여

1. 필요 시 이슈 또는 ADR 로 변경 의도를 먼저 기록 (권장)
2. 브랜치 생성 후 작업, `make fmt validate test` 통과 확인
3. PR 본문에 `make plan SVC=<별칭>` 출력 요약 첨부
4. `OWNERS`/`OWNERS_ALIASES` 매트릭스 기준 자동 리뷰어 할당, CI 통과 후 머지
5. 머지 후 `make backup` 으로 상태 백업 확인

자세한 절차는 `CONTRIBUTING.md` 와 `docs/AGENTS.md` 참조.

## 운영 및 연락처

| 역할 | 위치 | 책임 |
| --- | --- | --- |
| 저장소 소유자 | `OWNERS` | 핵심 결정, 머지 권한 |
| 리뷰어 별칭 | `OWNERS_ALIASES` | 영역별 리뷰어 그룹 |
| CI/CD 정책 | `.github/AGENTS.md` | 워크플로 규약 |
| 비밀 회전 | 1Password vault `homelab` | 비밀 회전, 접근 제어 |
| 장애 대응 | `docs/` 런북 | 서비스별 절차 |

문제 발생 시 GitHub Issues 사용.
보안 관련 비밀 노출은 공개 이슈 대신 저장소 소유자에게 직접 연락.

## 추가 문서

| 문서 | 경로 | 내용 |
| --- | --- | --- |
| 프로젝트 지식 베이스 | `AGENTS.md` | 구조, 규약, 안티패턴 |
| 아키텍처 | `ARCHITECTURE.md` | 계층, 데이터 흐름 |
| 코드 스타일 | `CODE_STYLE.md` | Terraform/Go/템플릿 규약 |
| 기여 절차 | `CONTRIBUTING.md` | PR 정책, ADR 절차 |
| 의존 관계 | `DEPENDENCY_MAP.md` | 모듈/워크스페이스 의존성 |
| 런북/ADR | `docs/` | 운영 절차 및 결정 기록 |
| 워크플로 | `.github/` | CI/CD 정의 |
| 템플릿 사용법 | `*/templates/AGENTS.md` | 워크스페이스별 템플릿 규약 |

---

라이선스는 `LICENSE` 참조.