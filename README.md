# Homelab Infrastructure Monorepo / 홈랩 인프라 모노레포

[![CI/CD: GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=githubactions&logoColor=white)](#ci--cd--ci--cd)
![Terraform 1.10.5](https://img.shields.io/badge/Terraform-1.10.5-7B42BC?logo=terraform&logoColor=white)
[![Manual apply: disabled](https://img.shields.io/badge/manual_apply-disabled-critical)](#ci--cd--ci--cd)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)

> 모든 변경은 GitHub Actions를 통해 배포됩니다. 로컬에서 `terraform apply`를 실행하지 마세요.
> All changes deploy via GitHub Actions. Never run `terraform apply` locally.

---

## 요약 (Korean summary)

개인 홈랩과 소규모 외부(클라우드) 통합을 위한 **인프라스트럭처-코드(IaC) 모노레포**입니다. 모든 워크스페이스는 `NNN-SERVICE` 형식의 평탄한(flat) 식별자로 명명되며, 최상위 `Makefile` 하나로 일관되게 제어합니다. **애플리케이션 소스는 포함하지 않으며**, 배포에 필요한 Terraform 매니페스트, `.tftpl` 템플릿, Docker Compose 스택, 보조 Go 스크립트, 1Password 시크릿 주입 정의만 보관합니다. 중앙 오케스트레이터(`100-pve`)가 호스트 정의(단일 진실 공급원)를 토대로 LXC/VM 라이프사이클을 관리하고, 후속 워크스페이스는 `remote_state`를 통해 이를 소비합니다.

## Summary (English, condensed)

A **monorepo of self-contained infrastructure-as-code (IaC) workspaces** for a personal homelab and a small set of external integrations. Workspaces use a flat `NNN-SERVICE` naming convention and are driven by a single top-level `Makefile`. This repo contains **no application sources**—only Terraform manifests, `.tftpl` templates, Docker Compose stacks, helper Go scripts, and 1Password secret wiring needed to deploy them. A central orchestrator workspace provisions the LXC/VM fleet; downstream workspaces consume its `remote_state`.

---

## 상태 / Status

운영자가 작업 전에 한눈에 확인하는 요약입니다.

| 항목 / Item | 값 / Value | 비고 / Note |
| --- | --- | --- |
| 배포 채널 / Deploy channel | GitHub Actions only | `master` 브랜치 push/PR |
| 수동 `apply` / Manual apply | **비활성화 / disabled** | 로컬에서 실행 금지 |
| Terraform 버전 / Version | `>= 1.7, < 2.0` (현재 1.10.5) | `terraform { required_version }` 강제 |
| 시크릿 소스 / Secrets source | 1Password CLI (`op`) | `modules/shared/onepassword-secrets` |
| 네트워크 / Network | `<LAN_SUBNET>/24` (placeholder) | 하드코딩된 사설 IP 미사용 |
| LXC/VM 식별자 / VMIDs | 워크스페이스별 placeholder | 레포에 정수 하드코딩 금지 |

---

## 아키텍처 / Architecture

### 요청 흐름 / Request flow

1. **선언 / Declare** — `100-pve/envs/prod/hosts.tf`(SSoT)가 호스트 IP, VMID, 역할, 포트를 정의합니다.
2. **조달 / Provision** — `100-pve`가 Proxmox API로 LXC/VM 라이프사이클을 생성/갱신/삭제합니다.
3. **렌더 / Render** — `config-renderer` 모듈이 `*.tftpl`을 `configs/` 산출물로 변환합니다.
4. **배포 / Deploy** — SSH를 통해 `/opt/<service>/`로 렌더된 구성을 전송합니다.
5. **인그레스 / Ingress** — Traefik(`102-traefik`)이 L7 라우팅을 담당하며, 외부 트래픽은 Cloudflare Tunnel(`300-cloudflare`)을 통과합니다.
6. **관측 / Observe** — Filebeat가 각 호스트에서 로그를 수집해 Logstash(`105-elk`)로 전송하고, ILM 정책으로 인덱스를 회전합니다.
7. **시크릿 / Secrets** — 1Password vault가 런타임 자격증명을 주입하며, 모든 토큰은 평문으로 저장되지 않습니다.
8. **자동화 / Automate** — GitHub Actions가 `plan`/`apply`를 실행하고 `tfplan` 아티팩트를 보존합니다.

### 컴포넌트 책임 / Component responsibilities

| 컴포넌트 / Component | 역할 / Responsibility | 위치 / Location |
| --- | --- | --- |
| `100-pve` | 중앙 오케스트레이터 (Tier 0) | Proxmox 호스트 정의 + 모든 LXC/VM 조달 |
| `102-traefik` | 인그레스 프록시 | L7 라우팅, TLS 종료 |
| `103-coredns` | 서비스 디스커버리 | CoreDNS 영역 및 forward 설정 |
| `105-elk` | 로그/검색 스택 | Elasticsearch + Logstash + Kibana |
| `112-mcphub` | MCP 도구 허브 | n8n 패치, Playwright, Proxmox MCP |
| `300-cloudflare` | 외부 DNS/Access/Logpush | Tunnel, Access 정책, Logpush 작업 |
| `modules/proxmox/*` | 재사용 모듈 | `lxc`, `vm`, `lxc-config`, `vm-config`, `config-renderer` |
| `modules/shared/onepassword-secrets` | 시크릿 주입 | 1Password vault → Terraform |

---

## 저장소 구성 / Repository Layout

실제 최상위 디렉터리만 반영합니다(존재하지 않는 경로는 발명하지 않습니다).

```text
.
├── AGENTS.md                    # 자동 생성기가 소비하는 프로젝트 지식 베이스
├── ARCHITECTURE.md              # 전체 아키텍처 레퍼런스
├── CODE_STYLE.md                # 명명/파일/변수/템플릿 컨벤션
├── CONTRIBUTING.md              # 기여 가이드
├── DEPENDENCY_MAP.md            # 모듈 의존성 그래프 + 템플릿 인벤토리
├── LICENSE                      # Apache-2.0
├── Makefile                     # 최상위 작업 라우터 (모든 워크스페이스 진입점)
├── OWNERS                       # 코드 오너십 (CODEOWNERS 스타일)
├── OWNERS_ALIASES               # 오너 별칭 정의
├── README.md                    # 본 문서
├── build.env                    # 빌드 환경 변수
├── 103-coredns/                 # CoreDNS 서비스 디스커버리
│   ├── AGENTS.md
│   ├── README.md
│   └── templates/               # *.tftpl + docker-compose + filebeat
├── 105-elk/                     # ELK 관측성 스택
│   ├── AGENTS.md
│   ├── docker-compose.yml
│   ├── ilm-policy.json
│   ├── scripts/                 # setup-ilm, setup-watcher, remove-promtail (Go)
│   ├── config/                  # 렌더된 산출물 + Dockerfile.logstash
│   ├── templates/               # *.tftpl 일체
│   └── terraform/               # main.tf / variables.tf / outputs.tf ...
├── 112-mcphub/                  # MCPHub 도구 허브
│   ├── AGENTS.md
│   ├── README.md
│   ├── Dockerfile.dev-browser
│   ├── Dockerfile.playwright
│   ├── Dockerfile.proxmox
│   ├── mcp_servers.json
│   ├── validate_mcps.py
│   ├── patches/                 # n8n 라이선스 패치 (license.js 등)
│   ├── op-mcp-server/           # Node.js MCP 서버 (1Password 연동)
│   ├── config/                  # entrypoint 패처 + Filebeat + SDK 스키마 패치
│   └── templates/               # *.tftpl 일체
└── 300-cloudflare/              # Cloudflare DNS/Access/Logpush/Tunnel
    ├── AGENTS.md
    ├── README.md
    ├── access.tf
    ├── checks.tf
    ├── dns.tf
    ├── identity-provider.tf
    ├── locals.tf
    ├── logpush.tf
    ├── main.tf
    ├── onepassword.tf
    ├── outputs-homelab.tf
    ├── outputs-jclee.tf
    ├── outputs-synology.tf
    └── outputs.tf
```

> 참고 / Note: `Makefile`은 `jclee`, `pve`, `runner`, `traefik`, `elk`, `supabase`, `archon`, `n8n`, `mcphub`, `oc`, `synology`, `youtube`, `cloudflare`, `github`, `safetywallet`, `slack`, `gcp` 등 더 많은 워크스페이스 별칭을 라우팅합니다. 현재 트리에 보이는 디렉터리는 `103-coredns`, `105-elk`, `112-mcphub`, `300-cloudflare` 네 곳입니다.

---

## 워크스페이스 / Workspaces

레포에 실제 존재하는 워크스페이스입니다.

| 디렉터리 / Directory | 별칭 / Alias | 역할 / Role | 진입점 / Entry point |
| --- | --- | --- | --- |
| `103-coredns/` | `coredns` | 사내 서비스 디스커버리, 영역 정의 | `templates/Corefile.tftpl` |
| `105-elk/` | `elk` | Elasticsearch + Logstash + Kibana, ILM | `terraform/main.tf` |
| `112-mcphub/` | `mcphub` | MCP 도구 허브(n8n, Playwright, Proxmox) | `templates/*.tftpl` |
| `300-cloudflare/` | `cloudflare` | 외부 DNS/Access/Logpush/Tunnel/IdP | `main.tf` |

### 번호 규칙 / Numbering convention

| 범위 / Range | 용도 / Purpose | 예시 / Examples |
| --- | --- | --- |
| `1–79` | 예약 (예비 식별자) | — |
| `80` | 물리 호스트/하이퍼바이저 | `80-jclee` |
| `100s` | Proxmox 인프라 | `100-pve`, `102-traefik`, `105-elk` |
| `200s` | VM 기반 앱 | `200-oc`, `215-synology`, `220-youtube` |
| `300s` | 외부 서비스 | `300-cloudflare`, `301-github`, `320-slack` |
| `400s` | 퍼블릭 클라우드 | `400-gcp` |

### 계층과 적용 순서 / Tiers and apply order

| 계층 / Tier | 워크스페이스 / Workspaces | 적용 순서 / Order |
| --- | --- | --- |
| 0 (핵심 / core) | `100-pve` | **먼저** — 모든 LXC/VM을 조달 |
| 1 (인프라 / infra) | `102-traefik`, `103-coredns`, `105-elk`, `108-archon` | `remote_state` 소비, 병렬 가능 |
| 2 (앱 / apps) | `110-n8n`, `112-mcphub`, `2xx-*` | Tier 1 완료 후 |
| 외부 / External | `300-cloudflare`, `301-github`, `320-slack`, `400-gcp` | Proxmox 비의존, 독립 |
| 템플릿 전용 / Template-only | 10개 워크스페이스 | `.tf` 없음, `100-pve`가 렌더링 |

---

## 빠른 시작 / Quick Start

### 1. 사전 준비 / Prerequisites

| 도구 / Tool | 용도 / Purpose |
| --- | --- |
| `terraform` 1.10.5 | IaC 엔진 |
| `make` | 작업 라우터 |
| `op` (1Password CLI) | 시크릿 주입 |
| `git`, `ssh`, `curl` | 일반 도구 |

### 2. 워크스페이스 선택 / Pick a workspace

별칭 또는 전체 경로를 사용합니다.

```bash
# 별칭 사용
make SVC=cloudflare plan      # → 300-cloudflare/
make SVC=elk plan             # → 105-elk/terraform/
make SVC=coredns plan         # → 103-coredns/

# 전체 경로 사용
make SVC=300-cloudflare plan
```

### 3. 플랜 검토 / Plan & review

```bash
make SVC=cloudflare plan
# 출력: tfplan 파일이 워크스페이스 디렉터리에 생성됨
```

### 4. CI/CD로 적용 / Apply via CI/CD

```bash
git checkout -b feat/<short-description>
git add .
git commit -m "feat(300-cloudflare): <변경 요약>"
git push origin feat/<short-description>
# GitHub에서 PR 생성 → Actions가 plan/verify 실행 → master 머지 시 apply
```

> 절대 로컬에서 `terraform apply`를 실행하지 마세요.
> Never run `terraform apply` locally.

---

## 설정 / Configuration

### 구성 파이프라인 / Config pipeline

```text
hosts.tf (SSoT)
  └─► module.hosts (100-pve)
        ├─► onepassword_secrets (1Password)
        └─► config_renderer (templatefile)
              └─► {NNN}-{svc}/templates/*.tftpl
                    └─► {NNN}-{svc}/configs/  (rendered)
                          └─► SSH deploy → /opt/<service>/
```

### 시크릿 / Secrets

- 모든 자격증명은 1Password vault에서 주입됩니다.
- `modules/shared/onepassword-secrets/main.tf`로 정의합니다.
- 평문 토큰은 커밋하지 마세요. PR의 `pre-commit` 훅이 차단합니다.

### 변수 명명 / Variable naming

- 워크스페이스 변수: `inputs.tf` (또는 `variables.tf`)에 정의
- 공통 변수: `modules/shared/*`에 정의
- 상세 컨벤션은 [`CODE_STYLE.md`](./CODE_STYLE.md) 참조

---

## 명령어 참조 / Commands Reference

| 명령 / Command | 설명 / Description |
| --- | --- |
| `make help` | 사용 가능한 모든 타깃 출력 |
| `make SVC=<alias> init` | Terraform 초기화 (백엔드/프로바이더 다운로드) |
| `make SVC=<alias> plan` | 실행 계획 생성 (`tfplan` 아티팩트) |
| `make SVC=<alias> verify` | `terraform validate` + 추가 검사 |
| `make SVC=<alias> fmt` | 포맷 적용 |
| `make lint` | Go 보조 스크립트 + 템플릿 린트 |
| `make lint-go` | Go 스크립트만 린트 |
| `make validate` | 워크스페이스 전반 검증 |
| `make drift-check` | 실제 인프라 vs 선언 비교 |
| `make test` | 전체 테스트 스위트 실행 |
| `make test-unit` | 단위 테스트 |
| `make test-integration` | 통합 테스트 |
| `make test-workspace` | 워크스페이스 회귀 테스트 |
| `make backup` | 상태 백업 |
| `make docs` | 문서 생성/갱신 |
| `make pre-commit-install` | Git 훅 설치 |
| `make pre-commit-run` | 훅 수동 실행 |
| `make setup` | 로컬 환경 1회 셋업 |

`<alias>` 자리에는 `cloudflare`, `elk`, `coredns`, `mcphub`, `pve`, `traefik`, `gcp` 등을 넣을 수 있습니다. 전체 매핑은 [`Makefile`](./Makefile)을 참조하세요.

---

## 로컬 개발 / Local Development

1. 저장소 클론 후 `pre-commit`을 설치합니다.
   ```bash
   git clone <repo-url>
   cd homelab
   make pre-commit-install
   ```
2. `build.env`를 검토해 로컬 빌드 변수를 확인합니다.
3. 작업할 워크스페이스의 `AGENTS.md`를 먼저 읽습니다 (워크스페이스별 컨벤션이 다를 수 있음).
4. 변경 후 다음 순서로 검증합니다.
   ```bash
   make SVC=<alias> fmt
   make SVC=<alias> plan
   make lint
   make test-unit
   ```
5. PR을 생성하면 GitHub Actions가 `plan`/`verify`/`docs`를 실행합니다.

---

## 테스트 / Testing

| 종류 / Type | 도구 / Tool | 위치 / Location |
| --- | --- | --- |
| 단위 / Unit | `terraform test` | 워크스페이스별 `tests/` |
| 통합 / Integration | `terraform test` (integration) | `tests/integration/` |
| 회귀 / Workspace | `make test-workspace` | 전체 워크스페이스 스모크 |
| 정적 분석 / Static | `tflint`, `tfsec`, `pre-commit` | `.pre-commit-config.yaml` |
| Go 스크립트 / Go scripts | `go test ./scripts/...` | `scripts/` (std-lib only) |

CI는 `pull_request` 이벤트에서 `lint`, `validate`, `plan`을 실행하고, `master` 머지 시에만 `apply`를 수행합니다.

---

## 기여 방법 / Contributing

1. 이슈 또는 ADR(`docs/adr/`)로 동기/설계 의도를 먼저 논의합니다.
2. `feat/<scope>-<short>` 형태의 브랜치를 생성합니다.
3. [`CODE_STYLE.md`](./CODE_STYLE.md)와 [`CONTRIBUTING.md`](./CONTRIBUTING.md)를 준수합니다.
4. 새 워크스페이스를 추가할 때는 `Makefile`의 `ALIAS_*`에 매핑을 등록합니다.
5. `make SVC=<alias> plan`과 `make lint`가 모두 통과해야 PR을 올릴 수 있습니다.
6. 리뷰어는 [`OWNERS`](./OWNERS)와 [`OWNERS_ALIASES`](./OWNERS_ALIASES)를 기준으로 자동 할당됩니다.

---

## 도움말 및 연락처 / Maintainers & Help

| 채널 / Channel | 위치 / Location |
| --- | --- |
| 소유자 / Code owners | [`OWNERS`](./OWNERS) |
| 오너 별칭 / Owner aliases | [`OWNERS_ALIASES`](./OWNERS_ALIASES) |
| 이슈 트래커 / Issue tracker | 저장소 Issues 탭 |
| 인시던트 대응 / Incidents | `docs/runbooks/` |
| 설계 결정 / ADRs | `docs/adr/` (append-only) |

긴급한 인프라 장애는 `docs/runbooks/`의 대응 플레이북을 먼저 확인하세요.

---

## 추가 문서 / Further Documentation

| 문서 / Document | 설명 / Description |
| --- | --- |
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | 전체 아키텍처 상세 레퍼런스 |
| [`DEPENDENCY_MAP.md`](./DEPENDENCY_MAP.md) | 모듈 의존성 그래프 + 템플릿 인벤토리 |
| [`CODE_STYLE.md`](./CODE_STYLE.md) | 명명, 파일 조직, 변수, 템플릿 컨벤션 |
| [`CONTRIBUTING.md`](./CONTRIBUTING.md) | PR 워크플로, 리뷰 기준, 커밋 규칙 |
| `AGENTS.md` | 자동 생성기용 프로젝트 지식 베이스 |
| `103-coredns/README.md` | CoreDNS 워크스페이스 안내 |
| `105-elk/README.md` | ELK 워크스페이스 안내 |
| `112-mcphub/README.md` | MCPHub 워크스페이스 안내 |
| `300-cloudflare/README.md` | Cloudflare 워크스페이스 안내 |
| `docs/adr/` | 아키텍처 결정 기록 (ADR) |
| `docs/runbooks/` | 운영 플레이북 |

---

## 라이선스 / License

이 프로젝트는 [`LICENSE`](./LICENSE) 파일에 명시된 라이선스를 따릅니다. 외부에 재배포할 경우 라이선스 전문을 함께 제공하세요.