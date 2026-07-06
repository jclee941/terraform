# jclee.me Homelab Infrastructure-as-Code

| ![Terraform](https://img.shields.io/badge/terraform-1.10.5-844FBA?logo=terraform&logoColor=white) | ![Proxmox](https://img.shields.io/badge/proxmox-orchestrator-E57000?logo=proxmox&logoColor=white) | ![Cloudflare](https://img.shields.io/badge/cloudflare-external-F38020?logo=cloudflare&logoColor=white) | ![License](https://img.shields.io/badge/license-internal-lightgrey) |
|---|---|---|---|

## 개요

`jclee.me` 홈랩 인프라를 코드로 관리하는 단일 저장소입니다.  
Proxmox LXC/VM 플릿(Tier 0)을 Terraform으로 프로비저닝하고, Tier 1 서비스(Traefik, ELK, CoreDNS, MCP Hub)와 외부 통합(Cloudflare, GCP)을 같은 명령 체계(`make`)로 다룹니다.  
비밀값은 1Password에서 주입하고, 템플릿 렌더링으로 컨테이너 설정을 생성하며, GitHub Actions가 변경 사항을 검증·적용합니다.

## Overview

A single repository that codifies the `jclee.me` homelab.  
Tier 0 Proxmox LXC/VM fleet is provisioned with Terraform, Tier 1 services (Traefik, ELK, CoreDNS, MCP Hub) and external integrations (Cloudflare, GCP) share one command surface (`make`).  
Secrets come from 1Password, container configs are rendered from templates, and GitHub Actions gate and apply changes.

## 현재 상태 / Status

| 영역 / Area | 상태 / Status | 비고 / Notes |
|---|---|---|
| Terraform | 1.10.5 (`>= 1.7, < 2.0`) | 루트 `Makefile`, 워크스페이스별 진입 |
| 인증 백엔드 | 1Password (`homelab` vault) | `modules/shared/onepassword-secrets/` |
| CI/CD | GitHub Actions | 동시성 직렬화로 충돌 방지 |
| 핵심 모듈 | 10 (`proxmox`, `shared`, `cloudflare`, `elasticstack`) | `modules/` 하위 |
| Cloudflare Access | 비활성화 / Removed | DNS · Tunnel · Workers 중심 |
| 외부 도메인 | `jclee.me` | 사설 서브넷 자리표시자 사용 |

## 빠른 흐름 / Quick Flow

1. `make help` — 사용 가능한 `SVC` 별칭과 타깃 출력
2. `SVC=pve make init` — Proxmox 오케스트레이터 초기화
3. `SVC=pve make plan` → `SVC=pve make apply` — 플릿 적용
4. `SVC=elk make plan` — Tier 1(ELK) 변경 검토
5. `SVC=cloudflare make plan` — 외부(DNS/Tunnel/Workers) 변경
6. `make lint` · `make test-unit` · `make drift-check` — 검증 루프

## 목차 / Table of Contents

1. [Purpose / 패키지 구성](#1-purpose--패키지-구성)
2. [Status / 상태 상세](#2-status--상태-상세)
3. [First Files to Read](#3-first-files-to-read)
4. [API or Entry Points / 진입점](#4-api-or-entry-points--진입점)
5. [Quickstart / 사용법](#5-quickstart--사용법)
6. [Maintainers / 책임자](#6-maintainers--책임자)
7. [Further Documentation / 추가 문서](#7-further-documentation--추가-문서)

---

## 1. Purpose / 패키지 구성

### 1.1 무엇을 하는가 / What it does

- Proxmox 위 LXC/VM 자원의 단일 진실 공급원(`100-pve/envs/prod/hosts.tf`)을 유지합니다.
- Tier 1 앱(Traefik, ELK, CoreDNS, MCP Hub)을 템플릿 기반 Docker Compose로 렌더링해 배포합니다.
- Cloudflare DNS, Tunnel, Workers를 별도 Terraform 루트로 외부 자원을 다룹니다.
- 1Password 비밀을 환경 변수와 모듈 입력으로 흘려보내 코드에 평문 비밀을 두지 않습니다.

### 1.2 누구를 위한가 / Who uses it

- 홈랩 운영자 1인(SRE/DevOps 역할 사인)
- 홈랩 자산을 IaC로 재현하려는 사용자
- MCP·Workers 같은 자가 호스팅 서비스를 실험하는 개발자

### 1.3 디렉터리 구성 / Layout

루트의 핵심 파일은 메타데이터(`AGENTS.md`, `ARCHITECTURE.md`, `CODE_STYLE.md`, `CONTRIBUTING.md`, `DEPENDENCY_MAP.md`, `LICENSE`, `Makefile`, `OWNERS`, `OWNERS_ALIASES`, `README.md`, `build.env`)입니다.  
이 스냅샷에 보이는 워크스페이스는 다음과 같습니다.

| 경로 / Path | 역할 / Role | 별칭 / Alias |
|---|---|---|
| `103-coredns/` | 분할 DNS 템플릿 | (직접 지정) |
| `105-elk/` | ELK 스택(Terraform + 템플릿 + 스크립트) | `elk` |
| `112-mcphub/` | MCP Hub + 1Password Connect 자산 | `mcphub` |
| `300-cloudflare/` | Cloudflare DNS/Tunnel/Workers + 스크립트 | `cloudflare` |

전체 워크스페이스 별칭은 `Makefile`의 `ALIAS_*` 정의가 단일 출처입니다.

| 별칭 / Alias | 경로 / Path |
|---|---|
| `jclee` | `80-jclee` |
| `pve` | `100-pve/terraform` |
| `runner` | `101-runner` |
| `traefik` | `102-traefik/terraform` |
| `coredns` | `103-coredns` |
| `elk` | `105-elk/terraform` |
| `mcphub` | `112-mcphub` |
| `oc` | `200-oc` |
| `synology` | `215-synology` |
| `youtube` | `220-youtube` |
| `cloudflare` | `300-cloudflare/terraform` |
| `safetywallet` | `310-safetywallet` |
| `gcp` | `400-gcp` |

## 2. Status / 상태 상세

### 2.1 프로덕션 준비도 / Production readiness

| 영역 / Area | 단계 / Stage | 메모 / Memo |
|---|---|---|
| Tier 0 (Proxmox 플릿) | 운영 중 / In use | 상태 파일 일부 워크스페이스에 공존 (`100-pve/terraform`, `105-elk/terraform`) |
| Tier 1 (앱 서비스) | 운영 중 / In use | 템플릿 렌더링 중심, 수동 컨테이너 실행 보조 |
| 외부 통합 / External | 운영 중 / In use | Cloudflare Workers 별도 자식 스코프 운영 |
| 모듈 재사용성 / Modules | 안정 / Stable | `modules/proxmox`, `modules/cloudflare`, `modules/elasticstack` |
| Access 보호 / Cloudflare Access | 제거됨 / Removed | 의도적 비활성, 재도입 시 ADR 필요 |

### 2.2 운영 시 주의 / Operator caveats

- 상태 파일이 워크스페이스와 공존합니다(`100-pve/terraform`, `105-elk/terraform`). 신규 워크스페이스는 원격 백엔드로 분리하세요.
- 사설 서브넷 IP는 저장소 메타데이터에 하드코딩하지 않습니다. 실제 주소를 쓸 때는 자리표시자(`<homelab-host>/24`)를 유지하세요.
- Cloudflare Access 자원은 의도적으로 제거된 상태입니다. 재추가하려면 `docs/`의 ADR 절차에 따라 결정 기록을 남기세요.

## 3. First Files to Read

| 순서 / Order | 파일 / File | 이유 / Why |
|---|---|---|
| 1 | `AGENTS.md` | 저장소 전체 지식 베이스, 규약, 안티패턴 |
| 2 | `Makefile` | 워크스페이스 진입점과 명령 계약 |
| 3 | `100-pve/terraform/main.tf` | Tier 0 오케스트레이터 진입 |
| 4 | `100-pve/envs/prod/hosts.tf` | 호스트·IP·VMID 단일 진실 |
| 5 | `modules/` 하위 `main.tf` | 재사용 모듈 인터페이스 확인 |
| 6 | `{NNN}-{svc}/templates/*.tftpl` | 서비스 설정 렌더링 원본 |
| 7 | `OWNERS`, `OWNERS_ALIASES` | 변경 승인 권한 매트릭스 |
| 8 | `CONTRIBUTING.md`, `CODE_STYLE.md` | 기여 절차와 코드 규약 |

## 4. API or Entry Points / 진입점

### 4.1 Make 명령 계약 / Make command contract

루트 `Makefile`의 `SVC` 변수가 워크스페이스를 가리킵니다. 짧은 별칭(`pve`, `elk`, `cloudflare` 등)과 전체 경로(`100-pve`)를 모두 받습니다.

| 타깃 / Target | 설명 / Purpose | 예시 / Example |
|---|---|---|
| `help` | 사용 가능한 타깃과 별칭 출력 | `make help` |
| `init` | Terraform 초기화 | `SVC=pve make init` |
| `plan` | `tfpla` 플랜 파일 생성 | `SVC=traefik make plan` |
| `apply` | 플랜 적용 | `SVC=elk make apply` |
| `fmt` | `*.tf` 포맷(`TF_WORKSPACE_DIRS` 전체) | `make fmt` |
| `validate` | Terraform 검증 | `make validate` |
| `lint`, `lint-go` | 정적 분석 | `make lint` |
| `test`, `test-unit`, `test-integration`, `test-workspace` | 테스트 스위트 | `make test-unit` |
| `drift-check` | 실상태와 코드 차이 점검 | `make drift-check` |
| `backup` | 상태/플랜 백업 | `make backup` |
| `docs` | 문서 생성/검증 | `make docs` |
| `pre-commit-install`, `pre-commit-run` | pre-commit 훅 관리 | `make pre-commit-run` |
| `setup` | 환경 초기 셋업 | `make setup` |

### 4.2 모듈 진입점 / Module entry points

| 모듈 / Module | 위치 / Location | 사용처 / Consumers |
|---|---|---|
| `proxmox` 자원 | `modules/proxmox/*/main.tf` | `100-pve`, `102-traefik`, `105-elk`, `112-mcphub` 등 |
| `shared` 유틸 | `modules/shared/*/main.tf` | 비밀, 라벨, 공통 헬퍼 |
| `cloudflare` | `modules/cloudflare/tunnel/main.tf` 등 | `300-cloudflare` |
| `elasticstack` | `modules/elasticstack/*/main.tf` | `105-elk` |

### 4.3 워커 진입점 / Worker entry points

| 워커 / Worker | 위치 / Location |
|---|---|
| Synology 프록시 | `300-cloudflare/workers/synology-proxy/src/index.ts` |
| 기타 워커 | `300-cloudflare/workers/*/src/index.ts` |

## 5. Quickstart / 사용법

### 5.1 사전 요구 / Prerequisites

- Terraform 1.10.5(`>= 1.7, < 2.0`)
- Proxmox API 토큰, 1Password `homelab` 볼트 접근
- `make`, `pre-commit`, Go(검증 도구용)
- 도메인 `jclee.me`에 대한 Cloudflare 관리 권한

### 5.2 로컬 설정 / Local setup

```bash
# 의존성 설치
make setup

# pre-commit 훅
make pre-commit-install

# 환경 변수 템플릿 확인
cat build.env
```

### 5.3 첫 플랜 / First plan

```bash
# Tier 0 오케스트레이터(Proxmox)
SVC=pve make init
SVC=pve make plan   # tfpla 생성
SVC=pve make apply
```

### 5.4 Tier 1 변경 / Tier 1 changes

```bash
# 새 Traefik 라우트 추가 후
SVC=traefik make plan
SVC=traefik make apply

# ELK 인덱스 정책/로그 파이프라인 변경
SVC=elk make plan
SVC=elk make apply
```

### 5.5 외부 자원 / External changes

```bash
SVC=cloudflare make plan
SVC=cloudflare make apply
```

### 5.6 검증 루프 / Verification loop

| 검사 / Check | 명령 / Command |
|---|---|
| 포맷/검증 | `make fmt && make validate` |
| 정적 분석 | `make lint && make lint-go` |
| 단위 테스트 | `make test-unit` |
| 통합 테스트 | `make test-integration` |
| 워크스페이스 테스트 | `make test-workspace` |
| 드리프트 | `make drift-check` |
| 문서 검증 | `make docs` |

### 5.7 설정 항목 / Configuration knobs

| 항목 / Item | 위치 / Location | 비고 / Notes |
|---|---|---|
| 호스트/IP/VMID | `100-pve/envs/prod/hosts.tf` | 단일 진실 공급원 |
| 템플릿 변수 | `{NNN}-{svc}/templates/*.tftpl` | 백엔드 IP는 호스트 맵에서만 |
| 비밀 값 | 1Password `homelab` | 커밋 금지 |
| 라우트 정의 | `102-traefik/templates/*.yml.tftpl` | 호스트 변수만 참조 |
| ELK 파이프라인 | `105-elk/templates/logstash.conf.tftpl` | ILM·인증 가정 유지 |

## 6. Maintainers / 책임자

| 역할 / Role | 책임 / Responsibility | 참조 / Reference |
|---|---|---|
| 코드 오너 | 변경 승인, 라우팅 | `OWNERS`, `OWNERS_ALIASES` |
| 기여자 가이드 | 절차/규약 | `CONTRIBUTING.md` |
| 코드 스타일 | 식별자/구조 규약 | `CODE_STYLE.md` |
| 의존성 그래프 | 모듈/워크스페이스 맵 | `DEPENDENCY_MAP.md` |
| 운영 핸드오버 | 컨택 포인트 | `OWNERS` |

## 7. Further Documentation / 추가 문서

| 문서 / Document | 위치 / Location | 용도 / Purpose |
|---|---|---|
| 프로젝트 지식 베이스 | `AGENTS.md` | 구조·규약·안티패턴 |
| 아키텍처 | `ARCHITECTURE.md` | 시스템 경계, 데이터 흐름 요약 |
| 기여 절차 | `CONTRIBUTING.md` | PR 규칙, 리뷰 흐름 |
| 의존성 맵 | `DEPENDENCY_MAP.md` | 모듈·워크스페이스 관계 |
| 코드 스타일 | `CODE_STYLE.md` | Terraform/Go 규약 |
| 워크스페이스 노트 | `{NNN}-{svc}/README.md`, `{NNN}-{svc}/AGENTS.md` | 각 워크스페이스별 운영 메모 |
| 모듈 문서 | `modules/*/README.md` (있을 경우) | 모듈 사용법 |
| ADR / 런북 | `docs/` | 결정 기록, 운영 절차 |

### 7.1 도움말 받기 / Getting help

- 저장소 내 `AGENTS.md` → “WHERE TO LOOK” 표에서 작업별 위치를 먼저 확인하세요.
- 구체 워크스페이스 이슈는 해당 디렉터리의 `README.md`/`AGENTS.md`를 1차로 참조하세요.
- 정책/규약 분쟁은 `OWNERS_ALIASES`의 담당자에게 라우팅하세요.

### 7.2 라이선스 / License

저장소 내 `LICENSE` 파일의 조항을 따릅니다. 사내용(`internal`) 표기는 외부 배포가 아닌 운영 자산임을 알립니다.