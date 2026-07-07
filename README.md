# jclee.me Homelab Infrastructure

![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.7%2C%20%3C2.0-844FBA)
![Make](https://img.shields.io/badge/Make-operator%20entrypoint-427819)
![Go](https://img.shields.io/badge/Go-tooling-00ADD8)
![License](https://img.shields.io/badge/License-see%20LICENSE-blue)

`jclee.me` 홈랩 인프라를 코드로 관리하는 운영 저장소입니다.  
Terraform, Go/Python/Shell 운영 스크립트, 실행 가능한 런북을 통해
Proxmox 기반 서비스 구성, 러너 설정, Traefik 라우팅, 백업, 비밀 검증,
문서 검증을 일관된 명령으로 다룹니다.

English: This repository is the infrastructure-as-code and operations workspace
for the `jclee.me` homelab. It provides Terraform-oriented workflows,
operator scripts, and runbooks for provisioning, validation, backup, and
service recovery.

## 빠른 상태 / Quick Status

| 항목 | 현재 상태 | 운영자가 다음에 실행할 것 |
|---|---|---|
| 목적 | 홈랩 인프라 운영용 IaC 및 런북 | `make help` |
| 운영 상태 | 운영 환경을 대상으로 하는 작업 공간 | 변경 전 `make plan SVC=<alias>` |
| 주요 진입점 | `Makefile`, `scripts/`, `docs/runbooks/` | 표준 명령은 `make`로 시작 |
| 비밀 관리 | 1Password 기반 검증/동기화 스크립트 사용 | `go run scripts/validate-vault-secrets.go` |
| 백업/복구 | Terraform state 백업 및 복구 런북 제공 | `make backup`, `docs/runbooks/backup-restore.md` |
| 문서 품질 | Go 기반 문서 검증 도구 포함 | `go test ./scripts/validate-docs/...` |
| 소유권 | `OWNERS`, `OWNERS_ALIASES` 기준 | 변경 전 담당자 확인 |

## 운영 흐름 요약 / Operator Flow

1. 변경 범위 확인: `docs/`, `scripts/`, 또는 `NNN-service/` 작업 공간을 확인합니다.
2. 소유자 확인: [`OWNERS`](OWNERS)와 [`OWNERS_ALIASES`](OWNERS_ALIASES)를 봅니다.
3. 계획 생성: `make plan SVC=<alias-or-path>`로 Terraform 변경을 검토합니다.
4. 검증 실행: `make validate`, `make lint`, 필요한 Go 테스트를 실행합니다.
5. 적용 또는 복구: 승인 후 `make apply SVC=<alias-or-path>`를 사용하거나
   관련 [`docs/runbooks/`](docs/runbooks/) 런북을 따릅니다.

English: Operators usually start with ownership, run a scoped Terraform plan,
validate locally, then apply or follow a runbook for recovery.

## 목차 / Table of Contents

- [목적과 패키지 구성](#목적과-패키지-구성--purpose-and-package-contents)
- [주요 기능](#주요-기능--features)
- [상태와 지원 범위](#상태와-지원-범위--status-and-support)
- [먼저 읽을 파일](#먼저-읽을-파일--first-files-to-read)
- [아키텍처](#아키텍처--architecture)
- [엔트리포인트](#엔트리포인트--entry-points)
- [빠른 시작](#빠른-시작--quickstart)
- [설정](#설정--configuration)
- [명령어 참조](#명령어-참조--commands)
- [로컬 개발](#로컬-개발--local-development)
- [테스트와 검증](#테스트와-검증--testing-and-validation)
- [운영과 관측](#운영과-관측--operations-and-observability)
- [저장소 구조](#저장소-구조--repository-layout)
- [기여 가이드](#기여-가이드--contributing)
- [관리자와 문의](#관리자와-문의--maintainers-and-support)
- [문서 더 보기](#문서-더-보기--further-documentation)
- [라이선스](#라이선스--license)

## 목적과 패키지 구성 / Purpose and Package Contents

이 저장소는 홈랩 인프라를 반복 가능하고 검토 가능한 방식으로 관리합니다.

사용자는 다음 작업을 할 수 있습니다.

- Terraform 작업 공간의 초기화, 계획, 적용, 검증
- 서비스별 구성 템플릿과 운영 스크립트 관리
- Terraform state 백업 및 복구 절차 실행
- 1Password 기반 비밀 값 검증과 동기화
- 문서, 런북, 운영 절차의 품질 검증
- GitHub Actions runner와 Filebeat 설정 템플릿 관리
- 장애, 디스크 부족, 네트워크 문제, credential rotation 등 운영 런북 참조

English: The repository packages infrastructure definitions, command wrappers,
validation tools, and operational documentation for a homelab environment.

## 주요 기능 / Features

| 기능 | 설명 | 주요 파일 |
|---|---|---|
| Terraform 운영 명령 | 작업 공간별 `init`, `plan`, `apply`, `validate` 실행 | [`Makefile`](Makefile) |
| 작업 공간 alias | 짧은 서비스 이름을 실제 디렉터리로 해석 | [`Makefile`](Makefile) |
| 백업 자동화 | Terraform state 백업 설정과 실행 도구 | [`scripts/backup-tfstate.go`](scripts/backup-tfstate.go), [`scripts/setup-backups.go`](scripts/setup-backups.go) |
| 비밀 검증 | 1Password vault 기반 비밀 값 점검 | [`scripts/validate-vault-secrets.go`](scripts/validate-vault-secrets.go) |
| 문서 검증 | 런북과 문서 품질 검증 | [`scripts/validate-docs/`](scripts/validate-docs/) |
| Runner 구성 | GitHub Actions runner 등록/해제 스크립트 | [`101-runner/scripts/`](101-runner/scripts/) |
| Traefik 작업 공간 | reverse proxy 관련 Terraform 작업 공간 | [`102-traefik/`](102-traefik/) |
| 런북 | 장애 대응, 복구, rotation, drift 대응 | [`docs/runbooks/`](docs/runbooks/) |
| ADR | 주요 인프라 의사결정 기록 | [`docs/adr/`](docs/adr/) |

## 상태와 지원 범위 / Status and Support

이 저장소는 운영 홈랩을 대상으로 합니다.  
따라서 모든 변경은 계획, 검증, 소유자 확인 후 적용해야 합니다.

| 영역 | 상태 | 주의 |
|---|---|---|
| Terraform workflow | 사용 중 | `apply` 전 반드시 `plan` 확인 |
| 운영 스크립트 | 사용 중 | 로컬 환경 변수와 인증 필요 |
| 문서/런북 | 사용 중 | 실행 전 최신 서비스 상태 확인 |
| 101-runner | 구성 스크립트 포함 | runner token과 권한 필요 |
| 80-jclee | 개인 작업 공간 skeleton | 하위 README 확인 |
| 102-traefik | 서비스 작업 공간 포함 | 실제 Terraform 루트는 하위 구조 확인 |
| Deprecated 여부 | 폐기 아님 | 단, archive 문서는 과거 참고용 |

English: This is not a sample-only repository. It targets a real operational
environment and should be used with review and change control.

## 먼저 읽을 파일 / First Files to Read

| 목적 | 파일 |
|---|---|
| 전체 아키텍처 이해 | [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| 기여 절차 | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
| 코드 스타일 | [`CODE_STYLE.md`](CODE_STYLE.md) |
| 의존성 지도 | [`DEPENDENCY_MAP.md`](DEPENDENCY_MAP.md) |
| 소유권 | [`OWNERS`](OWNERS), [`OWNERS_ALIASES`](OWNERS_ALIASES) |
| 운영 런북 목록 | [`docs/runbooks/`](docs/runbooks/) |
| ADR 목록 | [`docs/adr/README.md`](docs/adr/README.md) |
| 백업 전략 | [`docs/backup-strategy.md`](docs/backup-strategy.md) |
| 비밀 관리 | [`docs/secret-management.md`](docs/secret-management.md) |
| Cloudflare token rotation | [`docs/cloudflare-token-rotation.md`](docs/cloudflare-token-rotation.md) |

## 아키텍처 / Architecture

이 저장소는 `Makefile`을 운영자용 단일 명령 계층으로 사용합니다.
서비스별 Terraform 루트나 스크립트는 `Makefile` alias 또는 직접 경로로 실행됩니다.

| 계층 | 역할 | 예시 |
|---|---|---|
| Command layer | 반복 가능한 운영 명령 제공 | `make plan SVC=traefik` |
| Workspace layer | 서비스별 IaC 또는 구성 보관 | `101-runner/`, `102-traefik/` |
| Script layer | 백업, 검증, 환경 설정 자동화 | `scripts/*.go`, `scripts/*.py`, `scripts/*.sh` |
| Documentation layer | ADR, 런북, 운영 정책 제공 | `docs/`, `docs/runbooks/` |
| Ownership layer | 리뷰와 승인 책임 정의 | `OWNERS`, `OWNERS_ALIASES` |

### 요청/변경 흐름

1. 사용자는 변경할 서비스 작업 공간 또는 문서를 선택합니다.
2. `OWNERS`에서 담당자와 리뷰 경로를 확인합니다.
3. `make plan SVC=<alias-or-path>`로 변경 범위를 확인합니다.
4. `make validate`와 관련 테스트를 실행합니다.
5. 승인 후 `make apply SVC=<alias-or-path>` 또는 런북 절차를 수행합니다.
6. 장애나 drift가 있으면 `docs/runbooks/`의 대응 문서를 따릅니다.

English: The architecture is intentionally command-centered. Operators do not
need to remember each tool invocation; most workflows start from `make`.

## 엔트리포인트 / Entry Points

| 유형 | 엔트리포인트 | 설명 |
|---|---|---|
| 운영 명령 | [`Makefile`](Makefile) | Terraform, 검증, 백업, 테스트 명령 |
| 환경 설정 | [`build.env`](build.env) | 빌드/운영 환경 변수의 기준 파일 |
| Go 스크립트 | [`scripts/`](scripts/) | 백업, vault, runbook, workflow 검증 도구 |
| 문서 검증 도구 | [`scripts/validate-docs/`](scripts/validate-docs/) | Go module 기반 문서 validator |
| Runner 관리 | [`101-runner/scripts/`](101-runner/scripts/) | repository runner 등록/해제/설정 |
| Runner 설정 | [`101-runner/config/`](101-runner/config/) | Filebeat 등 runner-side 구성 |
| Runner 템플릿 | [`101-runner/templates/`](101-runner/templates/) | 생성용 Filebeat 템플릿 |
| Traefik 작업 공간 | [`102-traefik/`](102-traefik/) | reverse proxy 관련 구성 |
| 운영 문서 | [`docs/runbooks/`](docs/runbooks/) | 장애 대응과 복구 절차 |

## 빠른 시작 / Quickstart

### 1. 필수 도구 확인

권장 도구는 다음과 같습니다.

| 도구 | 용도 | 참고 |
|---|---|---|
| Terraform | IaC plan/apply/validate | `>= 1.7, < 2.0` |
| Make | 표준 운영 명령 실행 | `make help` |
| Go | 운영 스크립트와 문서 검증 | `scripts/*.go` |
| Python 3 | 작업 공간 탐지 스크립트 | `scripts/detect-workspaces.py` |
| Shell | Linux 운영 스크립트 | `scripts/*.sh` |
| 1Password CLI | 비밀 조회/검증 | 환경에 맞게 로그인 필요 |

### 2. 저장소 확인

```bash
git status
make help
```

### 3. 대상 작업 공간 선택

`SVC`는 실제 경로 또는 alias를 받을 수 있습니다.

```bash
make plan SVC=runner
make plan SVC=102-traefik/terraform
```

### 4. 검증 실행

```bash
make validate
make lint
go test ./scripts/validate-docs/...
```

### 5. 변경 적용

```bash
make apply SVC=<alias-or-path>
```

운영 환경에서는 `apply` 전에 plan 결과와 소유자 승인을 확인하세요.

English: Start with `make help`, select a scoped service using `SVC`, run a plan,
validate locally, and apply only after review.

## 설정 / Configuration

### `SVC` 선택 규칙

`Makefile`은 `SVC` 값을 실제 Terraform 디렉터리로 해석합니다.

| 입력 예시 | 해석 방식 |
|---|---|
| `SVC=runner` | alias를 통해 `101-runner`로 해석 |
| `SVC=traefik` | alias를 통해 Traefik Terraform 루트로 해석 |
| `SVC=102-traefik/terraform` | 직접 경로로 사용 |
| `SVC=<path>` | alias가 없으면 경로로 사용 |

현재 `Makefile`에 정의된 alias는 다음과 같습니다.

| Alias | 대상 경로 |
|---|---|
| `jclee` | `80-jclee` |
| `pve` | `100-pve/terraform` |
| `runner` | `101-runner` |
| `traefik` | `102-traefik/terraform` |
| `elk` | `105-elk/terraform` |
| `mcphub` | `112-mcphub` |
| `oc` | `200-oc` |
| `synology` | `215-synology` |
| `youtube` | `220-youtube` |
| `cloudflare` | `300-cloudflare/terraform` |
| `safetywallet` | `310-safetywallet` |
| `gcp` | `400-gcp` |

일부 alias 대상은 이 체크아웃의 최상위 구조에 없을 수 있습니다.
그 경우 `Makefile`은 사용 가능한 디렉터리와 alias를 출력하고 종료합니다.

### 환경 변수와 비밀

비밀 값은 저장소에 커밋하지 않습니다.  
운영자는 로컬 shell, CI secret, 또는 1Password CLI를 통해 필요한 값을 제공해야 합니다.

| 구성 항목 | 관리 위치 | 비고 |
|---|---|---|
| 공통 build 환경 | [`build.env`](build.env) | 로컬 정책에 맞게 로드 |
| 1Password secret | 외부 vault | 검증 스크립트로 확인 |
| Terraform 변수 | 작업 공간별 파일 또는 환경 변수 | 민감 값 커밋 금지 |
| 백업 대상 | 백업 스크립트와 런북 | 환경별로 경로 확인 |

관련 문서:

- [`docs/secret-management.md`](docs/secret-management.md)
- [`docs/backup-strategy.md`](docs/backup-strategy.md)
- [`docs/runbooks/credential-rotation.md`](docs/runbooks/credential-rotation.md)

## 명령어 참조 / Commands

`Makefile`이 제공하는 주요 target은 다음과 같습니다.

| 명령 | 용도 | 예시 |
|---|---|---|
| `make help` | 사용 가능한 target 표시 | `make help` |
| `make init` | Terraform 초기화 | `make init SVC=runner` |
| `make plan` | Terraform plan 생성 | `make plan SVC=traefik` |
| `make apply` | Terraform 변경 적용 | `make apply SVC=<alias>` |
| `make verify` | 저장소 검증 묶음 실행 | `make verify` |
| `make lint` | lint 실행 | `make lint` |
| `make lint-go` | Go 코드 lint | `make lint-go` |
| `make fmt` | 포맷 적용 | `make fmt` |
| `make validate` | Terraform 및 저장소 검증 | `make validate` |
| `make drift-check` | drift 확인 | `make drift-check` |
| `make backup` | 백업 실행 | `make backup` |
| `make test` | 전체 테스트 | `make test` |
| `make test-unit` | unit 테스트 | `make test-unit` |
| `make test-integration` | integration 테스트 | `make test-integration` |
| `make test-workspace` | 특정 작업 공간 테스트 | `make test-workspace SVC=<alias>` |
| `make docs` | 문서 관련 작업 | `make docs` |
| `make pre-commit-install` | pre-commit hook 설치 | `make pre-commit-install` |
| `make pre-commit-run` | pre-commit hook 수동 실행 | `make pre-commit-run` |
| `make setup` | 로컬 운영 환경 설정 | `make setup` |

### 스크립트 직접 실행 예시

```bash
go run scripts/backup-tfstate.go
go run scripts/setup-backups.go
go run scripts/validate-vault-secrets.go
go run scripts/validate-runbooks.go
python3 scripts/detect-workspaces.py
```

### Runner 스크립트

`101-runner/scripts/`는 runner 등록과 해제를 위한 스크립트를 제공합니다.

```bash
101-runner/scripts/setup-runner
101-runner/scripts/register-repo
101-runner/scripts/register-all-repos
101-runner/scripts/unregister-all
```

동일한 기능의 Go 소스도 함께 보관됩니다.

| 실행 파일 | Go 소스 |
|---|---|
| `setup-runner` | `setup-runner.go` |
| `register-repo` | `register-repo.go` |
| `register-all-repos` | `register-all-repos.go` |
| `unregister-all` | `unregister-all.go` |

## 로컬 개발 / Local Development

### 권장 작업 순서

1. 브랜치 또는 작업 디렉터리 상태를 확인합니다.
2. 관련 문서와 `OWNERS`를 읽습니다.
3. 작은 단위로 변경합니다.
4. `make fmt`, `make validate`, 필요한 테스트를 실행합니다.
5. Terraform 변경은 반드시 plan 결과를 함께 검토합니다.
6. 운영 절차 변경은 관련 runbook 또는 ADR도 함께 갱신합니다.

### 코드 스타일

자세한 규칙은 [`CODE_STYLE.md`](CODE_STYLE.md)를 따릅니다.

요약:

- Terraform identifier는 명확하고 일관된 이름을 사용합니다.
- 변수와 output에는 설명을 둡니다.
- 스크립트는 목적별로 작게 유지합니다.
- 운영 문서는 실행 가능한 명령과 rollback 단계를 포함합니다.
- 민감 정보, 내부 주소, 토큰은 커밋하지 않습니다.

### 문서 작성

문서는 운영자가 바로 실행할 수 있게 작성합니다.

| 문서 유형 | 위치 | 작성 원칙 |
|---|---|---|
| ADR | `docs/adr/` | 결정 배경과 결과 기록 |
| Runbook | `docs/runbooks/` | 증상, 진단, 조치, rollback 포함 |
| Design | `docs/design/` | 구현 전 설계와 제약 기록 |
| Archive | `docs/archive/` | 과거 참고용 문서 보관 |

## 테스트와 검증 / Testing and Validation

### 기본 검증

```bash
make fmt
make validate
make lint
make test
```

### 문서 validator 테스트

```bash
cd scripts/validate-docs
go test ./...
```

또는 저장소 루트에서:

```bash
go test ./scripts/validate-docs/...
```

### 운영 전 체크리스트

| 체크 | 명령 또는 파일 |
|---|---|
| Terraform plan 확인 | `make plan SVC=<alias-or-path>` |
| Terraform validate | `make validate` |
| 문서 검증 | `go run scripts/validate-runbooks.go` |
| Vault secret 검증 | `go run scripts/validate-vault-secrets.go` |
| 백업 준비 확인 | `docs/runbooks/backup-restore.md` |
| drift 확인 | `make drift-check` |
| 소유자 확인 | `OWNERS` |

## 운영과 관측 / Operations and Observability

운영 중 문제가 발생하면 먼저 관련 runbook을 확인합니다.

| 상황 | 문서 |
|---|---|
| 서비스 장애 | [`docs/runbooks/service-down.md`](docs/runbooks/service-down.md) |
| 서비스 배포 | [`docs/runbooks/service-deployment.md`](docs/runbooks/service-deployment.md) |
| 네트워크 문제 | [`docs/runbooks/network-issues.md`](docs/runbooks/network-issues.md) |
| 디스크 부족 | [`docs/runbooks/disk-full.md`](docs/runbooks/disk-full.md) |
| 백업/복구 | [`docs/runbooks/backup-restore.md`](docs/runbooks/backup-restore.md) |
| 재해 복구 | [`docs/runbooks/disaster-recovery.md`](docs/runbooks/disaster-recovery.md) |
| Terraform state rollback | [`docs/runbooks/terraform-state-rollback.md`](docs/runbooks/terraform-state-rollback.md) |
| State locking | [`docs/runbooks/state-locking.md`](docs/runbooks/state-locking.md) |
| Drift detection | [`docs/runbooks/drift-detection.md`](docs/runbooks/drift-detection.md) |
| Credential rotation | [`docs/runbooks/credential-rotation.md`](docs/runbooks/credential-rotation.md) |
| MCP health check | [`docs/runbooks/mcp-health-check.md`](docs/runbooks/mcp-health-check.md) |
| Filebeat deployment | [`docs/runbooks/pve-filebeat-deployment.md`](docs/runbooks/pve-filebeat-deployment.md) |
| ELK migration | [`docs/runbooks/elk-index-migration.md`](docs/runbooks/elk-index-migration.md) |
| 일반 troubleshooting | [`docs/runbooks/troubleshooting.md`](docs/runbooks/troubleshooting.md) |

### 권한과 안전 장치

| 작업 | 필요한 권한 | 안전 장치 |
|---|---|---|
| Terraform plan | 대상 provider 조회 권한 | 읽기 중심, 결과 검토 |
| Terraform apply | 대상 provider 변경 권한 | 소유자 승인과 plan 확인 |
| Vault secret 검증 | 1Password vault 접근 | secret 값 출력 금지 |
| Runner 등록 | repository 또는 org runner 권한 | token 수명과 scope 제한 |
| 백업/복구 | state 저장소 접근 | 복구 전 현재 상태 보존 |
| Credential rotation | 대상 서비스 admin 권한 | rotation runbook 준수 |

## 저장소 구조 / Repository Layout

현재 제공된 최상위 구조는 다음과 같습니다.

```text
.
├── AGENTS.md
├── ARCHITECTURE.md
├── CODE_STYLE.md
├── CONTRIBUTING.md
├── DEPENDENCY_MAP.md
├── LICENSE
├── Makefile
├── OWNERS
├── OWNERS_ALIASES
├── README.md
├── build.env
├── docs/
├── scripts/
├── 101-runner/
├── 80-jclee/
└── 102-traefik/
```

### 주요 디렉터리

| 경로 | 역할 |
|---|---|
| `docs/` | ADR, runbook, 설계, 운영 문서 |
| `docs/adr/` | 아키텍처 결정 기록 |
| `docs/design/` | 설계 문서 |
| `docs/runbooks/` | 장애 대응과 운영 절차 |
| `docs/archive/` | 과거 문서 보관 |
| `scripts/` | 운영 자동화와 검증 스크립트 |
| `scripts/validate-docs/` | Go 기반 문서 검증 module |
| `101-runner/` | runner 구성, 스크립트, Filebeat 템플릿 |
| `80-jclee/` | 개인 작업 공간 skeleton |
| `102-traefik/` | Traefik 관련 작업 공간 |

## 기여 가이드 / Contributing

기여 전 [`CONTRIBUTING.md`](CONTRIBUTING.md)를 읽어 주세요.

기본 원칙:

- 변경 범위를 작게 유지합니다.
- 운영 변경은 plan, rollback, 관측 방법을 함께 제시합니다.
- 문서 변경은 실제 명령과 파일 경로를 검증합니다.
- secret, token, 내부 주소, 개인 인증 정보는 커밋하지 않습니다.
- 새 운영 절차는 `docs/runbooks/`에 추가하거나 기존 문서를 갱신합니다.
- 아키텍처 결정은 필요 시 `docs/adr/`에 기록합니다.

English: Contributions should be scoped, reviewable, and operationally safe.
Infrastructure changes need validation and a rollback path.

## 관리자와 문의 / Maintainers and Support

| 주제 | 위치 |
|---|---|
| 코드/문서 소유자 | [`OWNERS`](OWNERS) |
| 소유자 alias | [`OWNERS_ALIASES`](OWNERS_ALIASES) |
| 기여 절차 | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
| 운영 장애 대응 | [`docs/runbooks/`](docs/runbooks/) |
| 아키텍처 질문 | [`ARCHITECTURE.md`](ARCHITECTURE.md), [`docs/adr/`](docs/adr/) |

도움이 필요하면 먼저 관련 runbook과 소유자 파일을 확인하세요.  
긴급 운영 문제는 가장 가까운 장애 runbook에서 증상 확인, 완화,
복구 절차 순서로 진행합니다.

## 문서 더 보기 / Further Documentation

| 문서 | 내용 |
|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | 전체 아키텍처 |
| [`DEPENDENCY_MAP.md`](DEPENDENCY_MAP.md) | 구성 요소 의존성 |
| [`docs/documentation-inventory.md`](docs/documentation-inventory.md) | 문서 인벤토리 |
| [`docs/workspace-ordering.md`](docs/workspace-ordering.md) | 작업 공간 순서 |
| [`docs/module-release-process.md`](docs/module-release-process.md) | module release 절차 |
| [`docs/ALERTING-REFERENCE.md`](docs/ALERTING-REFERENCE.md) | 알림 참고 자료 |
| [`docs/cloudflare-token-rotation.md`](docs/cloudflare-token-rotation.md) | Cloudflare token rotation |
| [`docs/proxmox-pxe-install.md`](docs/proxmox-pxe-install.md) | Proxmox PXE 설치 |
| [`docs/legacy-diagnosis-report.md`](docs/legacy-diagnosis-report.md) | legacy 진단 참고 |
| [`docs/design/lxc-cloud-init-spec.md`](docs/design/lxc-cloud-init-spec.md) | LXC cloud-init 설계 |

## 라이선스 / License

라이선스 정보는 [`LICENSE`](LICENSE)를 확인하세요.