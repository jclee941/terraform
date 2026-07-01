# 홈랩 인프라 코드 — Homelab Infrastructure as Code

[![CI/CD: GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=githubactions&logoColor=white)](#ci--cd--ci--cd)
[![Terraform](https://img.shields.io/badge/Terraform-1.7_→_2.0-7B42BC?logo=terraform&logoColor=white)](https://developer.hashicorp.com/terraform)
[![Manual apply](https://img.shields.io/badge/manual_apply-disabled-critical)](#ci--cd--ci--cd)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)
[![Workspaces](https://img.shields.io/badge/workspaces-21-2ea44f)](#workspaces)

> 모든 변경은 GitHub Actions를 통해 배포됩니다. 로컬에서 `terraform apply`를 실행하지 마세요.
> All changes deploy via GitHub Actions. Never run `terraform apply` locally.

---

## 한국어 요약 (Korean summary)

개인 홈랩과 소규모 외부(클라우드) 통합을 단일 저장소로 관리하는 **인프라스트럭처-코드(IaC) 워크스페이스 모음**입니다. 각 워크스페이스는 `NNN-SERVICE` 형식의 평탄한(flat) 식별자로 명명되며, 최상위 `Makefile` 하나로 일관되게 제어됩니다. 이 저장소에는 **애플리케이션 소스가 포함되지 않으며**, 배포에 필요한 Terraform 매니페스트, `.tftpl` 템플릿, Docker Compose 스택, 보조 Go 스크립트, 1Password 시크릿 주입 정의만 보관합니다. 중앙 오케스트레이터 워크스페이스(`100-pve`)가 단일 진실 공급원(SSOT)에 정의된 호스트/네트워크 정보로 LXC/VM 라이프사이클을 만들고, 다른 워크스페이스는 `remote_state`로 이를 소비합니다. 모든 배포는 GitHub Actions를 통해서만 수행됩니다.

## Summary (English, condensed)

A **set of self-contained infrastructure-as-code workspaces** for a personal homelab and a small set of external integrations (DNS, identity, secrets, cloud). Workspaces use a flat `NNN-SERVICE` naming convention driven by a single top-level `Makefile`. The repository contains **no application sources**—only Terraform manifests, `.tftpl` templates, Docker Compose stacks, helper Go scripts, and 1Password secret wiring required to deploy them. A central orchestrator workspace provisions the LXC/VM fleet from a single source of truth, and downstream workspaces consume its `remote_state`. Deployments run exclusively through GitHub Actions.

---

## 한눈에 보기 / At a Glance

운영자가 작업 전에 한 번에 확인하는 운영 상태 요약입니다. / Operator-facing status summary.

| 항목 / Item | 값 / Value | 비고 / Notes |
| --- | --- | --- |
| 배포 채널 / Deploy channel | GitHub Actions only | `master` 브랜치 push/PR |
| 수동 `apply` / Manual apply | **disabled** | 로컬 실행 금지 / do not run locally |
| Terraform 버전 / Version | `>= 1.7, < 2.0` (현재 1.10.5) | 모듈별 `required_version` 강제 |
| 시크릿 소스 / Secrets source | 1Password CLI (`op`) | `modules/shared/onepassword-secrets` |
| 도메인 / Domain | `jclee.me` | 외부 워크스페이스가 사용 |
| 서브넷 / Subnet | RFC1918 사설망 | `AGENTS.md` 참조 (저장소에 IP 미기재) |
| 워크스페이스 수 / Workspaces | 21 | `80`–`400` 평탄 식별자 |
| 모듈 수 / Local modules | 6 | `modules/proxmox/*`, `modules/shared/*` |
| CI/CD 실행기 / Runner | `101-runner` LXC | GitHub Actions self-hosted |

## 운영 흐름 / Operator Flow

저장소가 의도하는 동작 순서를 6단계로 요약합니다. / Six-step request flow.

1. 운영자가 `master`에 push 또는 PR을 올립니다. / Operator pushes to `master` (or opens a PR).
2. `101-runner`의 self-hosted GitHub Actions가 워크플로를 실행합니다. / A self-hosted runner on LXC 101 picks up the workflow.
3. 변경된 워크스페이스에 대해 `terraform init / plan`이 실행되며 결과를 PR에 코멘트로 남깁니다. / `init / plan` runs for the changed workspace; the plan is posted as a PR comment.
4. CI가 1Password 참조, 템플릿 렌더링, 검증 체크(`checks.tf`)를 수행합니다. / CI verifies 1Password references, renders templates, runs `checks.tf`.
5. `master` 머지 후 동일 러너가 `terraform apply`를 실행합니다(로컬에서는 절대 실행 금지). / After merge, the same runner runs `apply`—never locally.
6. `100-pve`는 변경된 호스트 정의에 따라 Proxmox LXC/VM을 만들고, 다른 워크스페이스는 `remote_state`로 그 결과를 읽어 서비스 매니페스트를 적용합니다. / `100-pve` reconciles the Proxmox fleet; downstream workspaces consume its `remote_state` and apply their manifests.

---

## Purpose / Package Contents

### 무엇을 위한 저장소인가 / What this is

개인 홈랩(Proxmox 기반 LXC/VM)과 외부 서비스 통합(Cloudflare DNS/Access/Tunnel, 1Password 비밀 저장소, GitHub, GCP 등)을 코드로 선언하고, GitHub Actions를 통해 안전하게 배포하기 위한 IaC 저장소입니다. 이 저장소는 **런타임 애플리케이션 코드를 호스팅하지 않습니다.** 그 목적은 다음 세 가지로 좁혀집니다.

1. **선언적 호스트 모델 유지** — LXC/VM 크기, IP, 역할을 `100-pve/envs/prod/hosts.tf` 한 곳에서 관리합니다.
2. **템플릿 기반 설정 배포** — `.tftpl` 파일을 호스트/시크릿 정보로 렌더링하여 각 노드에 SSH 배포합니다.
3. **CI/CD 게이팅** — 모든 변경이 GitHub Actions를 거치도록 강제하고, 수동 `apply`를 차단합니다.

### 이 저장소가 다루는 영역 / Scope

| 영역 / Domain | 대표 워크스페이스 / Representative workspaces | 책임 / Responsibility |
| --- | --- | --- |
| 중앙 오케스트레이터 / Central orchestrator | `100-pve` | 호스트 정의, Proxmox LXC/VM 생성 |
| CI/CD / CI/CD | `101-runner` | self-hosted GitHub Actions |
| 인그레스 / Ingress | `102-traefik` | HTTPS 종단, 역방향 프록시 |
| 서비스 디스커버리 / Service discovery | `103-coredns` | 내부 DNS |
| 로깅 / Logging | `105-elk` | Elasticsearch/Logstash/Filebeat |
| 워크플로 / Workflow | `110-n8n` | 워크플로 오케스트레이션 |
| MCP 허브 / MCP hub | `112-mcphub` | MCP 서버 페더레이션 |
| 외부 SaaS / External SaaS | `300-cloudflare`, `301-github`, `320-slack` | DNS, 액세스, 공급자 설정 |
| 클라우드 / Cloud | `400-gcp` | GCP 프로젝트/리소스 |

### 의도적으로 포함하지 않은 것 / Explicitly out of scope

- 애플리케이션 소스 코드 (`src/`, `tests/e2e/`, 서비스 비지니스 로직 등)
- 비-IaC 노이즈다운 운영 도구(예: 상태 모니터링 대시보드 애플리케이션)
- 비-(Proxmox + 1Password + Terraform + GitHub Actions + Cloudflare/GCP/GitHub) 기술 스택 가정

---

## Workspaces

`NNN-SERVICE` 평탄 식별자 규칙을 따릅니다. `/80` 영역은 물리 자산, `/100s`는 Proxmox 인프라, `/200s`는 VM 기반 앱, `/300s`+`/400s`는 외부/클라우드를 의미합니다. 최상위 디렉터리는 다음 4개가 보이며, 그 외는 동일한 규칙으로 평탄하게 배치됩니다.

| 최상위 디렉터리 / Path | 형태 / Form | 비고 / Note |
| --- | --- | --- |
| `103-coredns/` | 템플릿 전용 / Template-only | `Corefile.tftpl`, `docker-compose.yml.tftpl`, `filebeat.yml.tftpl` |
| `105-elk/` | Terraform + 도우미 스크립트 + 템플릿 | `terraform/`, `templates/`, `config/`, `scripts/` |
| `112-mcphub/` | 다중 Docker 이미지 + MCP 설정 | `Dockerfile.dev-browser`, `Dockerfile.playwright`, `Dockerfile.proxmox`, `mcp_servers.json`, `validate_mcps.py` |
| `300-cloudflare/` | 순수 Terraform / Pure Terraform | `access.tf`, `dns.tf`, `identity-provider.tf`, `logpush.tf` |

`Makefile`은 단축 별칭(`pve`, `elk`, `mcphub`, `cloudflare` 등)을 제공해 긴 경로 없이 워크스페이스를 지정할 수 있습니다. 전체 별칭 표는 최상위 `Makefile` 상단의 `ALIAS_*` 줄을 참조하십시오.

---

## Status

| 측면 / Aspect | 상태 / Status | 근거 / Evidence |
| --- | --- | --- |
| 프로덕션 사용 / Production usage | 사용 중 / In use | 실제 홈랩 트래픽이 라우팅됨 |
| 수동 적용 가능성 / Local apply | **차단됨 / Blocked** | `Makefile`의 `apply` 타깃이 메시지만 출력하고 종료 |
| 시크릿 안전성 / Secret safety | 안전 / Safe | 평문 비밀 없음, 1Password 참조만 저장 |
| 문서화 / Documentation | 부분 / Partial | `ARCHITECTURE.md`, `DEPENDENCY_MAP.md`, `CODE_STYLE.md` 외 인-폴더 `AGENTS.md` 다수 |
| 테스트 / Automated tests | 부분 / Partial | `terraform test` (unit/integration/workspace) + `lint-go` |
| 폐기 예정 / Deprecation | 없음 / None | 활성 유지보수 중 |

---

## First Files to Read

처음 저장소를 열 때 이 순서로 읽으면 의도와 구조가 가장 빠르게 그려집니다.

| 순서 / Order | 파일 / File | 왜 읽는가 / Why read it |
| --- | --- | --- |
| 1 | `AGENTS.md` | 도메인, 서브넷, 워크스페이스 계층, 핵심 규약 요약 |
| 2 | `Makefile` | 평탄 워크스페이스 운영의 유일한 진입점 |
| 3 | `ARCHITECTURE.md` | 전체 아키텍처, 데이터 흐름, 모듈 책임 |
| 4 | `DEPENDENCY_MAP.md` | 모듈/워크스페이스 의존성, 템플릿 인벤토리 |
| 5 | `CODE_STYLE.md` | 네이밍, 파일 조직, 템플릿 변수 규약 |
| 6 | `CONTRIBUTING.md` | PR 절차, 워크플로 게이팅, ADR 절차 |
| 7 | 최상위 `README.md` | (이 문서) 운영자 진입 가이드 |

워크스페이스별로 작업할 때는 해당 디렉터리 안에 있는 `AGENTS.md`(예: `103-coredns/AGENTS.md`, `105-elk/AGENTS.md`, `112-mcphub/AGENTS.md`, `300-cloudflare/AGENTS.md`)를 먼저 읽으십시오.

---

## API or Entry Points

### 최상위 진입점 / Top-level entry point: `Makefile`

모든 명령은 최상위 `Makefile`을 통해 호출합니다. 기본 대상은 `SVC=100-pve`이며, 별칭(예: `SVC=elk`, `SVC=cloudflare`) 또는 경로(`SVC=300-cloudflare`) 모두 허용합니다.

| 타깃 / Target | 용도 / Purpose | 예시 / Example |
| --- | --- | --- |
| `help` | 사용 가능한 타깃 목록 | `make help` |
| `init` | 선택한 워크스페이스에 대해 `terraform init` | `make init SVC=cloudflare` |
| `plan` | `tfplan` 파일로 plan 저장 | `make plan SVC=pve` |
| `apply` | **차단됨 / Blocked** — CI/CD 사용 안내만 출력 | `make apply` (오류) |
| `verify` | `terraform validate` + 정책 검사 | `make verify SVC=elk` |
| `lint` | Terraform + Go 린트 (`lint-go`) | `make lint` |
| `fmt` | `terraform fmt -recursive` | `make fmt` |
| `validate` | 입력 변수/시크릿 참조 사전 검증 | `make validate SVC=mcphub` |
| `drift-check` | 실제 상태와 선언 상태 비교 | `make drift-check SVC=pve` |
| `test` | `test-unit test-integration test-workspace` 통합 실행 | `make test` |
| `pre-commit-install` | pre-commit 훅 설치 | `make pre-commit-install` |
| `pre-commit-run` | pre-commit 훅 수동 실행 | `make pre-commit-run` |
| `backup` | 상태/설정 백업 | `make backup` |
| `docs` | 문서 빌드/검증 | `make docs` |
| `setup` | 새 워크스페이스 부트스트랩 | `make setup SVC=300-github` |

### 워크스페이스 내부 진입점 / Per-workspace entry points

| 워크스페이스 / Workspace | 진입점 / Entry files | 비고 / Notes |
| --- | --- | --- |
| `100-pve` | `envs/prod/hosts.tf`, `locals.tf` | SSoT; 다른 워크스페이스가 `remote_state`로 소비 |
| `103-coredns` | `templates/Corefile.tftpl`, `templates/docker-compose.yml.tftpl` | `100-pve`가 렌더링 |
| `105-elk` | `terraform/main.tf`, `templates/logstash.conf.tftpl` | Terraform + 템플릿 동시 보유 |
| `112-mcphub` | `Dockerfile.dev-browser`, `Dockerfile.playwright`, `Dockerfile.proxmox`, `mcp_servers.json`, `validate_mcps.py` | 다중 컨테이너 + MCP 페더레이션 |
| `300-cloudflare` | `main.tf`, `dns.tf`, `access.tf`, `identity-provider.tf`, `logpush.tf` | 외부 워크스페이스 대표 사례 |

### Go 도우미 스크립트 / Helper Go scripts

`stdlib-only` 정책의 운영 스크립트가 `scripts/` 및 일부 워크스페이스(`105-elk/scripts/`)에 있습니다. 예: `setup-ilm.go`, `setup-watcher.go`, `remove-promtail.go`. 모두 `make lint-go` 대상의 린트 대상입니다.

---

## Quickstart / Usage

### 1. 사전 요구사항 / Prerequisites

| 항목 / Requirement | 용도 / Why | 확인 방법 / Verify |
| --- | --- | --- |
| Terraform `>= 1.7, < 2.0` | 모듈 `required_version` | `terraform version` |
| `op` (1Password CLI) | 시크릿 주입 | `op --version` |
| `task`, `make` | 워크플로 실행 | `make --version` |
| `pre-commit` (선택 / optional) | 로컬 훅 | `pre-commit --version` |
| GitHub Actions 접근 / Actions access | 배포 | `101-runner` LXC 사용 |

### 2. 단일 워크스페이스에 plan 적용 / Plan a single workspace

```bash
# 최상위에서 실행 / Run from repository root
make plan SVC=cloudflare        # 별칭 사용
make plan SVC=300-cloudflare    # 경로 직접 지정
```

산출물 `tfplan` 파일은 워크스페이스 디렉터리 안에 생성되며, PR 시 GitHub Actions 코멘트로 다시 게시됩니다.

### 3. 검증과 포맷 / Verify and format

```bash
make verify SVC=elk
make fmt
make lint
```

### 4. 변경 적용 / Apply changes

로컬에서는 적용하지 않습니다. `master`에 push 또는 PR을 병합하면 GitHub Actions가 동일한 `tfplan`을 적용합니다.

```bash
git push origin <branch>
# PR을 열고 squash-merge로 master에 반영합니다.
```

### 5. 새 워크스페이스 추가 / Add a new workspace

1. 최상위 디렉터리를 평탄 식별자로 생성합니다(예: `NNN-svcname/`).
2. `Makefile` 상단의 `ALIAS_*` 맵에 항목을 추가합니다(필요 시).
3. `100-pve/envs/prod/hosts.tf`에 호스트 항목을 추가합니다(LXC/VM을 만들 경우).
4. `Makefile` `setup` 타깃 또는 모듈 골격을 사용해 부트스트랩합니다.
5. 첫 커밋 전에 `terraform validate`, `terraform fmt -recursive`, `pre-commit-run`을 실행합니다.

### 6. 시크릿 회전 / Rotate a secret

1. 1Password vault에서 값을 갱신합니다.
2. `modules/shared/onepassword-secrets` 사용처의 참조 키가 필요 시 갱신되었는지 확인합니다.
3. 해당 워크스페이스에 `make plan SVC=...`로 영향 범위를 검토합니다.
4. PR을 만들고 CI가 새 참조로 plan/apply를 검증하도록 둡니다.

---

## Local Development

| 작업 / Task | 명령 / Command | 메모 / Notes |
| --- | --- | --- |
| 워크스페이스 초기화 / Initialize | `make init SVC=<name>` | 첫 실행 시 백엔드/프로바이더 다운로드 |
| 변수 사전 검증 / Validate inputs | `make validate SVC=<name>` | 1Password 참조 가용성 확인 |
| 포맷 일관화 / Format | `make fmt` | 저장소 전체 |
| 정책 검사 / Policy checks | `make verify SVC=<name>` | `checks.tf` 항목들 실행 |
| 드리프트 비교 / Drift inspection | `make drift-check SVC=<name>` | 실제 vs 선언 상태 |
| pre-commit 설치 / Install hooks | `make pre-commit-install` | 한 번만 |
| pre-commit 수동 실행 / Run hooks | `make pre-commit-run` | 커밋 전 권장 |
| 문서 빌드 / Build docs | `make docs` | 다이어그램/문서 일관성 검사 |
| 백업 / Backup | `make backup` | 상태/설정 스냅샷 |

모든 명령은 최상위 `Makefile` 기준입니다. 워크스페이스 디렉터리로 직접 `cd`해 `terraform`을 호출하지 마십시오(수동 `apply`가 차단되지만 일관성을 위해 항상 `Makefile`을 사용).

### 환경 변수 / Environment variables

| 변수 / Variable | 용도 / Purpose | 기본값 / Default |
| --- | --- | --- |
| `SVC` | 대상 워크스페이스 식별자/별칭 | `100-pve` |
| `TF_DIR` | Makefile이 별칭 해석 후 결정 | `ALIAS_$(SVC)` 또는 `$(SVC)` |
| `OP_TOKEN`, `OP_VAULT` 등 | 1Password CLI 인증 | (런처/CI에서 주입) |

상세 키 목록은 `build.env`와 `modules/shared/onepassword-secrets`를 참조하십시오.

---

## Testing

| 테스트 종류 / Type | 명령 / Command | 범위 / Scope |
| --- | --- | --- |
| 유닛 / Unit | `make test-unit` (또는 `terraform test -filter=unit`) | 모듈 단위 |
| 통합 / Integration | `make test-integration` | 모듈 간 상호작용 |
| 워크스페이스 / Workspace | `make test-workspace` | 전체 워크스페이스 |
| Go 스크립트 / Go scripts | `make lint-go` | `stdlib-only` 정책, 포맷/정적 검사 |
| Pre-commit 훅 / Pre-commit hooks | `make pre-commit-run` | Terraform, Go, YAML 등 |

CI에서는 위 테스트들이 워크플로 단계로 묶여 실행되며, 실패 시 병합이 차단됩니다.

---

## Configuration

| 영역 / Area | 위치 / Location | 형식 / Format | 비고 / Notes |
| --- | --- | --- | --- |
| 호스트 진실 공급원 / Host SSoT | `100-pve/envs/prod/hosts.tf` | HCL | VMID, IP, 역할 정의 |
| 호스트 사이징 / Sizing | `100-pve/locals.tf` | HCL | 디스크/CPU/메모리 |
| 서비스 템플릿 / Service templates | `{워크스페이스}/templates/*.tftpl` | Terraform template | `100-pve`가 렌더링 |
| 렌더링된 결과 / Rendered output | `{워크스페이스}/configs/` | 실제 파일 | 절대 손으로 편집하지 않음 |
| 시크릿 / Secrets | 1Password vault + `modules/shared/onepassword-secrets` | 참조만 / References only | 평문 보관 금지 |
| 외부 정책 / External policy | `300-cloudflare/{access,dns,identity-provider,logpush}.tf` | HCL | 도메인/액세스 정책 |
| MCP 설정 / MCP settings | `112-mcphub/mcp_servers.json`, `templates/mcp_settings.json.tftpl` | JSON | `validate_mcps.py`로 검증 |

### 설정 파이프라인 / Config pipeline

개념 단계는 다음과 같습니다(`README.md` 다이어그램은 의도적으로 생략).

```
hosts.tf (SSoT) → module.hosts → onepassword_secrets + config_renderer
  → templatefile(.tftpl) → configs/ → SSH deploy to /opt/{service}/
```

자세한 단계는 `ARCHITECTURE.md`의 데이터 흐름 섹션을 참조하십시오.

---

## Contribution Guide

1. 변경 의도와 영향을 한 줄 PR 설명에 적습니다. `100-pve`의 호스트 변경이면 특히 명시합니다.
2. 워크스페이스별 `AGENTS.md`(있는 경우)와 `CODE_STYLE.md`를 따릅니다.
3. 작업 전에 `make fmt`, `make verify SVC=<name>`, `make pre-commit-run`을 실행합니다.
4. 의존성 그래프 영향은 `DEPENDENCY_MAP.md`로 점검합니다.
5. 아키텍처 변경은 `docs/adr/`에 새로운 ADR을 추가합니다(append-only, 기존 ADR은 폐기하지 말고 supersede합니다).
6. PR이 `master`에 병합되면 GitHub Actions가 `apply`를 수행합니다.

자세한 절차는 `CONTRIBUTING.md`를 참조하십시오. 책임 영역은 `OWNERS`와 `OWNERS_ALIASES`에 정의되어 있습니다.

---

## Maintainers / Points of Contact

| 역할 / Role | 식별 / Identification | 책임 / Responsibility |
| --- | --- | --- |
| 저장소 소유자 / Repository owner | `OWNERS` 참조 | 전체 가용성, 변경 승인 |
| 영역별 유지보수자 / Domain maintainers | `OWNERS_ALIASES` 참조 | 특정 워크스페이스/모듈 리뷰 |
| 운영 이슈 에스컬레이션 / Operational incidents | `docs/runbooks/`의 런북 사용 | LXC/VM 사고, 시크릿 회전 |
| 보안 / Security | 저장소 관리자에게 비공개 보고 | 평문 비밀 노출, 노출된 토큰 |

---

## Further Documentation

| 문서 / Document | 목적 / Purpose |
| --- | --- |
| `ARCHITECTURE.md` | 전체 아키텍처, 모듈 책임, 데이터 흐름 |
| `DEPENDENCY_MAP.md` | 모듈/워크스페이스 의존성 그래프, 템플릿 인벤토리 |
| `CODE_STYLE.md` | 네이밍, 파일 조직, 변수/템플릿 규약 |
| `CONTRIBUTING.md` | PR 절차, 워크플로 게이팅, ADR 절차 |
| `docs/adr/` | 아키텍처 결정 기록(append-only) |
| `docs/runbooks/` | 운영 런북(장애 대응, 복구) |
| `{워크스페이스}/AGENTS.md` | 각 워크스페이스의 국지 규약과 진입점 |

---

## License

이 저장소는 Apache License 2.0 하에 배포됩니다. 자세한 내용은 [`LICENSE`](./LICENSE) 파일을 참조하십시오.
This repository is distributed under the Apache License 2.0. See [`LICENSE`](./LICENSE) for details.