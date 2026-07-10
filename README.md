# jclee.me Homelab Infrastructure

[![Status: Active](./AGENTS.md)](./AGENTS.md)
[![Terraform 1.10.5](https://img.shields.io/badge/terraform-1.10.5-7B42BC)](https://www.terraform.io)
[![CI: GitHub Actions](https://img.shields.io/badge/CI-github%20actions-2088FF)](./.github/AGENTS.md)
[![License](./LICENSE)](./LICENSE)

Terraform 1.10.5로 관리하는 `jclee.me` 홈랩 인프라 코드베이스.
Proxmox LXC/VM 플릿 정의, ELK·MCP Hub·Cloudflare 구성 템플릿, 1Password 비밀 주입, GitHub Actions 직렬화 CI를 한 저장소에서 운영합니다.

> English: Terraform-managed homelab for `jclee.me` — Proxmox fleet definitions, rendered service templates (ELK, MCP Hub, Cloudflare), 1Password secret injection, and serialized GitHub Actions CI/CD.

## 상태

| 영역 | 상태 | 비고 |
| --- | --- | --- |
| 프로비저닝 도구 | 활성 | Terraform `>= 1.7, < 2.0` (현장 1.10.5) |
| 비밀 주입 | 활성 | 1Password vault `homelab`, 평문 커밋 금지 |
| CI/CD | 활성 | GitHub Actions, concurrency 기반 직렬화 |
| 호스트/IP/VMID SSoT | 활성 | 호스트 맵 기반 단일 진실원 |
| 외부 통합 | 활성 | Cloudflare DNS/Tunnel/Worker |
| 문서 정책 | 활성 | ADR append-only, runbook 실행 가능 형태 |
| 프로덕션 준비 | 활성 | 단일 운영자 + 잠재적 협업자 대상 |

## 빠른 실행 흐름

1. 워크스페이스 선택: `SVC=elk make plan` (기본값은 `pve`).
2. 비밀 주입: 1Password vault `homelab`에서 환경변수 노출.
3. 계획 작성: `terraform init` → `terraform plan -out=tfpla`.
4. 계획 적용: `terraform apply tfpla`.
5. 사후 검증: `make verify`, `make drift-check`, `make lint-go`.
6. 상태 백업: `make backup`.

## 목차

1. [목적과 사용자](#1-목적과-사용자)
2. [저장소 구성](#2-저장소-구성)
3. [아키텍처와 흐름](#3-아키텍처와-흐름)
4. [먼저 읽을 파일](#4-먼저-읽을-파일)
5. [엔트리 포인트](#5-엔트리-포인트)
6. [빠른 시작](#6-빠른-시작)
7. [명령어 참조](#7-명령어-참조)
8. [구성 및 비밀](#8-구성-및-비밀)
9. [로컬 개발](#9-로컬-개발)
10. [테스트](#10-테스트)
11. [기여와 정책](#11-기여와-정책)
12. [유지보수와 연락처](#12-유지보수와-연락처)
13. [라이선스](#13-라이선스)

---

## 1. 목적과 사용자

- 무엇을 하는가: `<homelab-subnet>/24` 사설망에서 Proxmox 클러스터와 LXC/VM 자산을 코드로 정의하고, Traefik·ELK·MCP Hub·Cloudflare 같은 부가 서비스 구성을 동일 저장소에서 템플릿으로 렌더링합니다.
- 왜 유용한가: 호스트·IP·VMID를 단일 진실원으로 두고, 1Password 비밀을 환경변수로 주입하며, GitHub Actions의 concurrency로 적용 순서를 직렬화해 안전하게 변경합니다.
- 사용 대상: 홈랩 운영자(개인)와 잠재적 협업자. 결과물은 `jclee.me` 도메인의 자가 호스팅 워크로드 사용자입니다.

## 2. 저장소 구성

루트는 정책 문서와 빌드 자산, 워크스페이스는 서비스 단위로 분리됩니다. 일부 워크스페이스는 평면 구조, 일부는 `terraform/` 하위 디렉터리를 사용합니다.

### 최상위 파일·디렉터리

| 경로 | 역할 |
| --- | --- |
| `AGENTS.md` | 프로젝트 지식 베이스, 규약, 안티패턴 |
| `ARCHITECTURE.md` | 아키텍처 결정과 흐름 |
| `CODE_STYLE.md` | 네이밍·구조 규약 |
| `CONTRIBUTING.md` | 기여 절차와 리뷰 정책 |
| `DEPENDENCY_MAP.md` | 모듈/워크스페이스 의존성 |
| `LICENSE` | 라이선스 전문 |
| `Makefile` | 단일 명령 진입 (별칭 → 경로 해석) |
| `OWNERS`, `OWNERS_ALIASES` | 리뷰어/승인자 명단 |
| `build.env` | 빌드 환경변수 정의 |
| `103-coredns/`, `105-elk/`, `112-mcphub/`, `300-cloudflare/` | 현재 채택된 서비스 워크스페이스 |

### Makefile 별칭 → 경로

`Makefile`은 짧은 별칭을 워크스페이스 경로로 해석합니다. 일부는 평면 구조, 일부는 `terraform/` 하위를 사용합니다.

| 별칭 | 해석 경로 | 비고 |
| --- | --- | --- |
| `pve` | `100-pve/terraform` | Tier 0 Proxmox 오케스트레이터 |
| `runner` | `101-runner` | GitHub Actions 러너 템플릿 |
| `traefik` | `102-traefik/terraform` | Tier 1 리버스 프록시 |
| `coredns` | `103-coredns` | 분할 DNS 템플릿 |
| `elk` | `105-elk/terraform` | Tier 1 ELK 스택 |
| `mcphub` | `112-mcphub` | MCP Hub + 1Password Connect 자산 |
| `oc` | `200-oc` | 외부 워크로드 |
| `synology` | `215-synology` | 평면 구조 예외 |
| `youtube` | `220-youtube` | 외부 워크로드 |
| `cloudflare` | `300-cloudflare/terraform` | Cloudflare DNS/Tunnel/Worker |
| `safetywallet` | `310-safetywallet` | 외부 워크로드 |
| `gcp` | `400-gcp` | GCP 통합 |
| `jclee` | `80-jclee` | 개인 워크스테이션 골격 |

### 워크스페이스 내부 구조 (현 저장소 기준)

| 워크스페이스 | 하위 디렉터리 | 산출물 |
| --- | --- | --- |
| `103-coredns/` | `templates/` | Corefile, docker-compose, filebeat |
| `105-elk/` | `terraform/`, `templates/`, `scripts/`, `config/` | ELK 스택, ILM, Filebeat, Logstash |
| `112-mcphub/` | `templates/`, `config/`, `op-mcp-server/` | MCP Hub 도커 스택, MCP 서버 자산 |
| `300-cloudflare/` | `terraform/`, `scripts/`, `inventory/`, `docs/`, `workers/` | DNS/Tunnel/Worker, 비밀 인벤토리 |

## 3. 아키텍처와 흐름

핵심 흐름은 “단일 진실원 → 템플릿 렌더링 → 워크스페이스 적용 → 검증” 입니다.

| 단계 | 위치 | 산출 |
| --- | --- | --- |
| 1. 호스트 정의 | `100-pve/envs/prod/hosts.tf` | 호스트/IP/VMID SSoT |
| 2. 모듈 조립 | `modules/proxmox/*`, `modules/shared/*`, `modules/cloudflare/*`, `modules/elasticstack/*` | 재사용 단위 |
| 3. 템플릿 렌더링 | `{NNN}-{svc}/templates/*.tftpl` | 서비스별 설정 파일 |
| 4. 워크스페이스 적용 | `105-elk/terraform/`, `300-cloudflare/terraform/` 등 | 인프라 상태 |
| 5. 비밀 주입 | 1Password vault `homelab` → 환경변수 | 자격 증명 |
| 6. 검증 | `make verify`, `make drift-check`, `make lint-go` | 상태 점검 |

요청 흐름(operator 관점):

1. `Makefile`의 `SVC`로 워크스페이스 선택.
2. 1Password에서 비밀 환경변수 주입.
3. `make init` → `make plan` → `tfpla` 검토.
4. `make apply` 또는 워크스페이스 루트에서 `terraform apply tfpla`.
5. `make verify`, `make drift-check`로 사후 확인.
6. `make backup`으로 상태 백업.

## 4. 먼저 읽을 파일

| 순서 | 파일 | 이유 |
| --- | --- | --- |
| 1 | `AGENTS.md` | 프로젝트 지식 베이스, 규약, 안티패턴 |
| 2 | `ARCHITECTURE.md` | 아키텍처 결정 근거 |
| 3 | `DEPENDENCY_MAP.md` | 모듈 간 의존성 |
| 4 | `CODE_STYLE.md` | 네이밍·구조 규약 |
| 5 | `CONTRIBUTING.md` | 기여 절차와 리뷰 정책 |
| 6 | `Makefile` | 명령 계약(별칭 → 경로) |

## 5. 엔트리 포인트

| 영역 | 위치 | 설명 |
| --- | --- | --- |
| ELK 프로비저닝 | `105-elk/terraform/main.tf` | Tier 1 ELK 스택의 Terraform 진입점 |
| Cloudflare 프로비저닝 | `300-cloudflare/terraform/` | DNS/Tunnel/Worker Terraform 진입점 |
| Worker 런타임 | `300-cloudflare/workers/*/src/index.ts` | Cloudflare Worker 코드 |
| ELK 운영 스크립트 | `105-elk/scripts/` | ILM 설정, watcher, promtail 제거 |
| Cloudflare 운영 스크립트 | `300-cloudflare/scripts/` | 감사, 수집, 동기화, Worker 배포, 바인딩 생성 |
| MCP Hub 자산 | `112-mcphub/op-mcp-server/` | 1Password Connect MCP 서버 |
| 빌드 진입 | `Makefile`, `build.env` | 단일 명령 진입 |

## 6. 빠른 시작

### 사전 요구사항

- Terraform 1.10.5 (`>= 1.7, < 2.0`).
- Proxmox 클러스터 접근 자격 증명(1Password vault `homelab`).
- Cloudflare API 토큰(해당 워크스페이스 사용 시).
- `make`, `find`, `git` 등 기본 CLI 도구.

### 절차

1. 저장소 클론 후 작업 디렉터리 진입.
   ```bash
   git clone <repo-url> jclee-infra
   cd jclee-infra
   ```
2. 1Password vault `homelab`에서 비밀 환경변수 주입(세부 절차는 `modules/shared/onepassword-secrets/` 참조).
3. 워크스페이스 초기화 및 계획.
   ```bash
   SVC=elk make init
   SVC=elk make plan
   ```
4. 계획 검토 후 적용.
   ```bash
   cd 105-elk/terraform
   terraform apply tfpla
   ```
5. 사후 검증.
   ```bash
   make verify
   make drift-check
   ```

## 7. 명령어 참조

`Makefile`은 모든 Terraform 작업의 단일 진입점입니다. `SVC` 변수로 워크스페이스를 선택합니다.

| 타깃 | 설명 | 예시 |
| --- | --- | --- |
| `init` | Terraform 초기화 | `SVC=elk make init` |
| `plan` | 계획 작성(`tfpla` 출력) | `SVC=pve make plan` |
| `apply` | 계획 적용 | `SVC=traefik make apply` |
| `verify` | 적용 결과 검증 | `make verify` |
| `drift-check` | 상태 드리프트 점검 | `make drift-check` |
| `lint` | Terraform 정적 검사 | `make lint` |
| `lint-go` | Go 스크립트 린트 | `make lint-go` |
| `fmt` | `*.tf` 포맷팅(워크스페이스 전체) | `make fmt` |
| `validate` | Terraform 유효성 검사 | `make validate` |
| `test` | 통합 테스트 실행 | `make test` |
| `test-unit` | 단위 테스트 실행 | `make test-unit` |
| `test-integration` | 통합 테스트 실행 | `make test-integration` |
| `test-workspace` | 워크스페이스 단위 검증 | `make test-workspace` |
| `backup` | 상태 백업 | `make backup` |
| `docs` | 문서 생성/검증 | `make docs` |
| `pre-commit-install` | pre-commit 훅 설치 | `make pre-commit-install` |
| `pre-commit-run` | pre-commit 훅 실행 | `make pre-commit-run` |
| `setup` | 로컬 환경 준비 | `make setup` |
| `help` | 타깃 목록 출력 | `make help` |

`SVC` 미지정 시 기본값은 `100-pve`(`pve` 별칭). 디렉터리가 존재하지 않으면 Makefile이 사용 가능한 별칭을 안내합니다.

## 8. 구성 및 비밀

| 항목 | 출처 | 비고 |
| --- | --- | --- |
| Terraform 변수 | `*.tf` (`description`, `type` 명시) | 변수/출력은 설명과 타입 필수 |
| 비밀 | 1Password vault `homelab` | 평문 커밋 금지, 환경변수 주입 |
| 상태 백엔드 | `*.tf`의 `backend` 블록 | 일부 워크스페이스는 로컬 백엔드(예외) |
| 템플릿 | `{workspace}/templates/*.tftpl` | 출력 파일 직접 편집 금지 |
| 외부 API 토큰 | Cloudflare, GitHub 등 | 워크스페이스별 환경변수 |

## 9. 로컬 개발

- 워크스페이스 단위 작업: `SVC=<alias> make init`.
- 형식 일관성: `make fmt` → `make validate` → `make lint`.
- 모듈 재사용: `modules/proxmox/`, `modules/shared/`, `modules/cloudflare/`, `modules/elasticstack/` 하위 모듈 활용.
- 새 Traefik 라우트: `102-traefik/templates/*.yml.tftpl`에 템플릿 작성. 백엔드 IP는 호스트 맵/템플릿 변수에서만 참조.
- 새 서비스 구성 변경: `{NNN}-{svc}/templates/*.tftpl` 수정, 렌더링된 출력은 직접 편집하지 않음.

## 10. 테스트

| 종류 | 명령 | 비고 |
| --- | --- | --- |
| 단위 테스트 | `make test-unit` | Terraform 기본 동작 |
| 통합 테스트 | `make test-integration` | 워크스페이스 간 상호작용 |
| 워크스페이스 테스트 | `make test-workspace` | 워크스페이스 단위 검증 |
| 정적 검증 | `make validate`, `make lint` | 포맷·스키마 검사 |
| 드리프트 점검 | `make drift-check` | 실제 상태와 코드 차이 |
| 백업 | `make backup` | 상태 백업 점검 |

테스트 정책: 기본적으로 provider mock 사용, 세부 정의는 `tests/AGENTS.md`.

## 11. 기여와 정책

- 기여 절차: `CONTRIBUTING.md`.
- 코드 스타일: `CODE_STYLE.md`.
- 의존성 규약: `DEPENDENCY_MAP.md`.
- 문서 정책: ADRs는 append-only, runbook은 실행 가능 형태로 유지(`docs/AGENTS.md`).
- CI 정책: GitHub Actions + concurrency 직렬화, 워크플로우 위임 구조 사용(`.github/AGENTS.md`).

### 규약 요약

- Terraform 식별자: `snake_case`, 단일 인스턴스 리소스는 `resource "x" "this"`.
- 템플릿/스크립트 파일: `kebab-case`.
- 변수/출력: `description`과 `type` 명시 필수.
- 인라인 cloud-init 금지: 앱 로직은 `templates/*.tftpl`에 둠.
- 비밀 평문 커밋 금지.

## 12. 유지보수와 연락처

| 역할 | 위치 |
| --- | --- |
| OWNERS | `./OWNERS` |
| OWNERS_ALIASES | `./OWNERS_ALIASES` |
| 정책/규약 | `./AGENTS.md`, `./CODE_STYLE.md`, `./CONTRIBUTING.md` |
| 운영 runbook | `./docs/` |
| 외부 워커 자산 | `./300-cloudflare/workers/` |

문제 발생 시 저장소 이슈 트래커 또는 `OWNERS` 파일의 담당자에게 연락합니다.

## 13. 라이선스

본 저장소는 `./LICENSE` 파일의 조항에 따라 배포됩니다.