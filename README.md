# jclee.me Homelab Infrastructure

[![Terraform 1.10.5](https://img.shields.io/badge/Terraform-1.10.5-7B42BC)](#quickstart--usage)
![Domain](https://img.shields.io/badge/Domain-jclee.me-0066CC)
[![Provisioning](https://img.shields.io/badge/State-Provisioned-green)](#status)
[![Secrets](https://img.shields.io/badge/Secrets-1Password-1572A3)](#quickstart--usage)

## 한눈에 보기

`jclee.me` 홈랩 인프라는 Terraform, 파일 템플릿, Go 보조 스크립트, Cloudflare Workers 로
Proxmox LXC/VM fleet 와 Tier 1 서비스(CoreDNS, ELK, MCP Hub), 그리고 외부 Cloudflare 자원을
한 저장소에서 재현 가능하게 관리합니다. 비밀값은 1Password `homelab` 볼트에서 주입되며,
CI 가 plan·apply·drift 를 직렬화해 상태를 보호합니다.

A Terraform-driven homelab for `jclee.me` that codifies the Proxmox fleet, Tier 1
services (CoreDNS, ELK, MCP Hub), and external Cloudflare resources in one repository.
Secrets come from 1Password; CI serializes plan, apply, and drift checks so state
stays consistent.

## Status

| 컴포넌트 / Component | 계층 / Tier | 수명 주기 / Lifecycle | 진입점 / Entry |
|----------------------|-------------|----------------------|----------------|
| 103-coredns | Tier 1 | 템플릿 전용 (Template-only) | `100-pve` 가 렌더링 |
| 105-elk | Tier 1 | Terraform + templates + scripts | `make SVC=elk plan` |
| 112-mcphub | Tier 1 | 템플릿 전용 (Template-only) | `100-pve` 가 렌더링 |
| 300-cloudflare | External | Terraform + Workers + scripts | `make SVC=cloudflare plan` |

## 운영 흐름 / Operator Flow

1. 작업할 워크스페이스 별칭을 정합니다 (`pve`, `elk`, `mcphub`, `cloudflare`, …).
2. `make SVC=<alias> init` 으로 provider 를 가져옵니다.
3. `make SVC=<alias> plan` 으로 `tfplan` 파일을 만듭니다.
4. `make SVC=<alias> apply` 로 적용하고, `verify` · `drift-check` 로 결과를 확인합니다.
5. CI 가 동일 `make` 타깃을 직렬로 다시 실행하므로, plan 없이 apply 가 진행되지 않습니다.

## 목차 / Table of Contents

- [Purpose / Package Contents](#purpose--package-contents)
- [Status](#status-1)
- [First Files to Read](#first-files-to-read)
- [API or Entry Points](#api-or-entry-points)
- [Quickstart / Usage](#quickstart--usage)
- [Maintainers / Points of Contact](#maintainers--points-of-contact)
- [Further Documentation](#further-documentation)

## Purpose / Package Contents

`jclee.me` 인프라는 단일 checkout 으로 재현 가능하도록 설계되었습니다.
Terraform 워크스페이스, 파일 템플릿, Go 보조 스크립트, Cloudflare Workers,
검증 도구를 묶어 homelab 전체를 코드로 표현합니다. 본 README 는 저장소 최상위에서
바로 보이는 네 워크스페이스를 중심으로 안내하며, `100-pve` (호스트 SSoT),
`102-traefik`, `215-synology`, 외부 provider 들은 동일한 수명 주기를 따릅니다.

### 패키지 구성 / Package Map

| 경로 / Path | 역할 / Role | 산출물 / Artifacts |
|-------------|-------------|--------------------|
| `103-coredns/` | CoreDNS split-horizon 설정 템플릿 | `templates/Corefile.tftpl`<br>`templates/docker-compose.yml.tftpl`<br>`templates/filebeat.yml.tftpl` |
| `105-elk/` | Elasticsearch / Logstash / Kibana 스택 | `terraform/*.tf`<br>`templates/*.tftpl`<br>`scripts/*.go`<br>`config/*` |
| `112-mcphub/` | MCP Hub (Playwright, Proxmox, 1Password Connect) | `templates/*.tftpl`<br>`Dockerfile.{dev-browser,playwright,proxmox}`<br>`op-mcp-server/`<br>`validate_mcps.py` |
| `300-cloudflare/` | Cloudflare DNS · Tunnel · Workers, 비밀값 인벤토리 | `terraform/*.tf`<br>`inventory/secrets.yaml`<br>`scripts/*.go`<br>`workers/synology-proxy/` |

## Status

위에 표시된 네 워크스페이스는 **운영 환경에 프로비저닝되어 유지 보수 중**입니다.
모든 비밀값은 1Password `homelab` 볼트에서 주입되며, 로컬 backend state 는
`105-elk/` 와 `100-pve/terraform/` 의 명시적 예외를 제외하면 권장되지 않습니다.
자세한 컨벤션과 운영 정책은 `CODE_STYLE.md`, `ARCHITECTURE.md` 를 참고하세요.

## First Files to Read

| 순서 / Order | 파일 / File | 이유 / Why |
|--------------|-------------|-----------|
| 1 | `Makefile` | 별칭 기반 명령 규약 (`SVC=<alias>`) 정의 |
| 2 | `OWNERS`, `OWNERS_ALIASES` | 코드 소유권과 리뷰 라우팅 |
| 3 | `103-coredns/README.md` | 가장 작은 Tier 1 예시 |
| 4 | `105-elk/README.md` | Terraform + 템플릿 + 스크립트 풀스택 |
| 5 | `112-mcphub/README.md` | MCP + 1Password Connect 패턴 |
| 6 | `300-cloudflare/README.md` | 외부 provider + Workers 모델 |
| 7 | `ARCHITECTURE.md`, `CODE_STYLE.md`, `DEPENDENCY_MAP.md` | 워크스페이스를 이해한 뒤 참고 |

## API or Entry Points

각 워크스페이스는 Terraform 진입점, 템플릿 렌더러, 보조 스크립트로 구성됩니다.
상위 `Makefile` 의 별칭 맵(`ALIAS_*`)이 모든 워크스페이스 명령의 단일 진입점입니다.

| 워크스페이스 / Workspace | Terraform 진입점 / TF Entry | 템플릿 / Templates | 보조 스크립트 / Helper Scripts |
|--------------------------|------------------------------|--------------------|--------------------------------|
| 103-coredns | — (템플릿 전용) | `templates/*.tftpl`<br>(`100-pve` 가 렌더링) | — |
| 105-elk | `105-elk/terraform/main.tf` | `105-elk/templates/*.tftpl` | `105-elk/scripts/setup-ilm.go`<br>`105-elk/scripts/setup-watcher.go`<br>`105-elk/scripts/remove-promtail.go` |
| 112-mcphub | — (템플릿 전용) | `112-mcphub/templates/*.tftpl`<br>(`100-pve` 가 렌더링) | `112-mcphub/op-mcp-server/index.mjs`<br>`112-mcphub/validate_mcps.py` |
| 300-cloudflare | `300-cloudflare/terraform/main.tf` | — | `300-cloudflare/scripts/audit.go`<br>`300-cloudflare/scripts/collect.go`<br>`300-cloudflare/scripts/deploy-worker.go`<br>`300-cloudflare/scripts/generate-bindings.go`<br>`300-cloudflare/scripts/sync.go`<br>`300-cloudflare/workers/synology-proxy/` |

## Quickstart / Usage

### 사전 준비 / Prerequisites

- Terraform `>= 1.7, < 2.0` (저장소는 `build.env` 에서 `1.10.5` 로 고정)
- `make`, `go` (보조 스크립트용), `docker compose` (렌더링된 서비스 구동)
- 1Password CLI 인증 (`op signin`, vault: `homelab`)

### 자주 쓰는 명령 / Common Commands

```bash
# 워크스페이스 초기화
make SVC=elk init

# plan 작성 후 tfplan 으로 저장
make SVC=elk plan

# 저장된 plan 적용
make SVC=elk apply

# 출력 검증 및 drift 확인
make SVC=elk verify
make drift-check
```

### 로컬 개발 루프 / Local Development Loop

1. 관련 `templates/*.tftpl` 또는 `terraform/*.tf` 를 수정합니다.
2. `make fmt` 와 `make validate` 로 저장소 전체 Terraform 디렉터리를 린트합니다.
3. `make test` (단위 + 통합) 와 `make test-workspace SVC=<alias>` 로 검증합니다.
4. PR 을 올리면 CI 가 동일 `make` 타깃을 직렬로 실행합니다.

### 참고 / Configuration Notes

- 서브넷과 호스트 IP 는 `100-pve/envs/prod/hosts.tf` 가 단일 진실 공급원 (SSoT) 입니다.
- Traefik 라우트 백엔드 IP 는 호스트 맵 / 템플릿 변수에서만 가져옵니다.
- ELK 의 ILM 과 인증 가정은 `105-elk/templates/logstash.conf.tftpl` 와
  `modules/elasticstack/` 에서 변경하지 않습니다.
- Cloudflare Access 자원은 제거되어 있으며, 스크립트와 Workers 는 별도 child scope 입니다.

## Maintainers / Points of Contact

| 역할 / Role | 담당 / Contact | 비고 / Notes |
|-------------|----------------|-------------|
| 저장소 소유자 / Repo owner | `@jclee941` | `100-pve`, secrets, 공유 모듈 변경 승인 |
| 코드 오너 / Code owners | `OWNERS`, `OWNERS_ALIASES` 참고 | 디렉터리·계층별 리뷰 라우팅 |
| 문서 / Docs | `docs/AGENTS.md` 참고 | ADR 은 append-only, runbook 은 실행 가능하게 유지 |

도움이 필요하면 이슈를 열거나 `OWNERS` 의 당직 메인테이너에게 연락하세요.

## Further Documentation

| 문서 / Document | 설명 / Purpose |
|-----------------|----------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | 계층 모델, 모듈 레이아웃, 데이터 흐름 |
| [DEPENDENCY_MAP.md](DEPENDENCY_MAP.md) | 외부 모듈 · provider 의존성 |
| [CODE_STYLE.md](CODE_STYLE.md) | Terraform, Go, 템플릿 컨벤션 |
| [CONTRIBUTING.md](CONTRIBUTING.md) | PR 및 리뷰 워크플로 |
| [LICENSE](LICENSE) | 라이선스 전문 |
| [103-coredns/README.md](103-coredns/README.md) | Split DNS 워크스페이스 안내 |
| [105-elk/terraform/README.md](105-elk/terraform/README.md) | ELK 워크스페이스 안내 |
| [112-mcphub/README.md](112-mcphub/README.md) | MCP Hub 워크스페이스 안내 |
| [300-cloudflare/README.md](300-cloudflare/README.md) | Cloudflare 워크스페이스 안내 |