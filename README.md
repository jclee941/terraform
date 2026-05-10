<think>
The user wants me to generate a README.md file in Korean for a Terraform-based homelab infrastructure project. Let me analyze the project structure and content to create a comprehensive README.

Key information from the provided files:
1. This is a Terraform monorepo for jclee.me
2. Domain: jclee.me
3. Subnet: 192.168.50.0/24
4. Terraform version: 1.10.5
5. 21 workspaces across 4 tiers
6. 6 modules for Proxmox and shared infrastructure
7. Uses 1Password secret injection
8. GitHub Actions CI/CD
9. Makefile with various targets for terraform operations

I need to generate a clean, professional README.md in Korean with:
- Title
- Description
- Features
- Installation
- Usage
- Project structure
- Contribution guide

Let me write this in Korean with proper Markdown formatting.
</think>

# Terraform Homelab Infrastructure

> **jclee.me** Homelab 인프라 관리용 Terraform 모노레포

## 📋 개요

이 저장소는 `jclee.me` 도메인의 Homelab 인프라를 코드형 인프라(IaC)로 관리합니다. Proxmox 기반 LXC/VM 클러스터, 네트워킹, 모니터링, 외부 서비스를 Terraform 워크스페이스를 통해 프로비저닝하며, 1Password 시크릿 주입과 GitHub Actions CI/CD를 활용합니다.

- **도메인**: `jclee.me`
- **서브넷**: `192.168.50.0/24`
- **Terraform**: 1.10.5
- **21개 워크스페이스** (4개 티어)
- **6개 모듈** (Proxmox 및 공유 인프라)

## ✨ 주요 기능

| 기능 | 설명 |
|------|------|
| **모듈형架构** | 재사용 가능한 Terraform 모듈 (Proxmox, Shared) |
| **워크스페이스 기반 배포** | Tier별 의존성 관리 및 순차적 적용 |
| **1Password 통합** | 시크릿 자동 주입을 통한 보안 강화 |
| **GitHub Actions CI/CD** | Pull Request 기반 검증 및 자동 배포 |
| **멀티 티어 네트워킹** | 내부 인프라 (1-255) 및 외부 서비스 (300+) 구분 |
| **포괄적 테스트** | 단위 테스트, 통합 테스트, e2e 테스트 지원 |
| **ELK 스택 모니터링** | Filebeat, Elasticsearch, Kibana 기반 로깅 |

## 🏗️ 프로젝트 구조

```
/
├── Makefile                    # 개발자 CLI 도구
├── AGENTS.md                   # AI 에이전트용 지침
├── ARCHITECTURE.md             # 시스템 토폴로지 문서
├── CODE_STYLE.md               # 코딩 컨벤션
├── DEPENDENCY_MAP.md           # 모듈 의존성 맵
│
├── 110-n8n/                    # N8N 워크스페이스
│   ├── Dockerfile.n8n
│   ├── patches/                # 라이선스 패치
│   └── templates/              # Docker/Terraform 템플릿
│
├── tests/                      # 테스트 suites
│   ├── workspaces/             # 워크스페이스별 테스트
│   │   ├── elk/                # ELK 스택 테스트
│   │   ├── pve/                # Proxmox 테스트
│   │   ├── traefik/            # Traefik 테스트
│   │   └── ...                 # 기타 워크스페이스
│   ├── integration/            # 통합 테스트
│   └── unit/                   # 단위 테스트
│
├── modules/                    # Terraform 모듈
│   ├── shared/                 # 공통 모듈
│   │   ├── README.md
│   │   └── main.tf
│   └── proxmox/                # Proxmox 리소스 모듈
│       ├── README.md
│       └── main.tf
│
└── docs/                       # 문서
    ├── runbooks/               # 운영 절차서
    └── adr/                    # 아키텍처 결정 기록
```

## 📦 워크스페이스 티어

| 티어 | 워크스페이스 | 설명 |
|------|------------|------|
| **Tier 0: 코어** | `100-pve` | 중앙 오케스트레이터. 모든 LXC/VM 생명주기 관리 |
| **Tier 1: 인프라** | `102-traefik`, `105-elk`, `108-archon` | `remote_state` 소비 인프라 서비스 |
| **Tier 2: 애플리케이션** | `110-n8n`, `107-supabase`, `112-mcphub` | 워크로드 서비스 |
| **Tier 3: 외부** | `300-cloudflare`, `301-github`, `400-gcp` | 클라우드 공급자 연동 |

## 🚀 시작하기

### 전제 조건

- Terraform 1.10.5 이상
- GNU Make
- Proxmox VE 서버 접속 정보
- 1Password CLI (`op`) 및 로그인 세션

### 환경 설정

```bash
# 저장소 클론
git clone https://github.com/jclee/terraform-homelab.git
cd terraform-homelab

# Terraform 초기화
make init SVC=pve

# 형식 검사
make fmt

#Lint 실행
make lint
```

## 📖 사용법

### Makefile 명령어

```bash
# Terraform 워크스페이스 관리
make init SVC=100-pve           # 초기화
make plan SVC=100-pve           # 실행 계획 생성
make apply SVC=100-pve          # 적용 (CI/CD 권장)
make validate SVC=100-pve       # 검증

# 테스트 실행
make test                      # 전체 테스트
make test-unit                 # 단위 테스트
make test-integration          # 통합 테스트

# 문서 및 품질
make docs                      # 모듈 README 생성
make lint                      # Linter 실행
make security                  # 보안 스캔
```

### 워크스페이스 별칭

`SVC` 변수에 별칭을 사용하여 빠르게 워크스페이스 지정:

| 별칭 | 워크스페이스 | 용도 |
|------|------------|------|
| `pve` | `100-pve` | Proxmox 코어 |
| `traefik` | `102-traefik` | 리버스 프록시 |
| `elk` | `105-elk` | ELK 스택 |
| `n8n` | `110-n8n` | 자동화 플랫폼 |
| `cloudflare` | `300-cloudflare` | DNS 및 CDN |
| `gcp` | `400-gcp` | Google Cloud |
| `synology` | `215-synology` | NAS 백업 |

**예시**:

```bash
make plan SVC=pve           # 100-pve 워크스페이스 계획
make plan SVC=elk          # 105-elk 워크스페이스 계획
make plan SVC=cloudflare   # 300-cloudflare 워크스페이스 계획
```

## 📂 모듈 참조

### `modules/shared`

공통 인프라 모듈

```hcl
module "shared" {
  source = "./modules/shared"
  # ...
}
```

### `modules/proxmox`

Proxmox 리소스 모듈 (LXC, VM, 네트워크)

```hcl
module "proxmox" {
  source = "./modules/proxmox"
  # ...
}
```

자세한 모듈 문서는 각 디렉토리의 `README.md`를 참조하세요.

## 📚 문서索引

| 문서 | 용도 |
|------|------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | 전체 시스템 토폴로지 및 서비스 관계 |
| [DEPENDENCY_MAP.md](DEPENDENCY_MAP.md) | 모듈 의존성 그래프 |
| [CODE_STYLE.md](CODE_STYLE.md) | 명명 규칙 및 파일 구조 |
| [docs/runbooks/](docs/runbooks/) | 운영 절차 및 장애 대응 가이드 |
| [docs/adr/](docs/adr/) | 아키텍처 결정 기록 |

## 🤝 기여 가이드

### 커밋 규칙

1. **브랜치 생성**: `git checkout -b feature/workspace-name`
2. **변경 적용**: Terraform 코드 작성
3. **형식 검사**: `make fmt && make lint`
4. **테스트 실행**: `make test`
5. **PR 제출**: master 브랜치로 병합 요청

### 코드 스타일

- Terraform 파일 형식: `terraform fmt` 사용
- 변수 명명: snake_case 규칙 준수
- 리소스 명명: `{workspace}_{resource_type}_{name}` 패턴
- 문서화: 모든 모듈에 `README.md` 포함 필수

자세한 내용은 [CODE_STYLE.md](CODE_STYLE.md) 및 [CONTRIBUTING.md](CONTRIBUTING.md)를 참조하세요.

## ⚠️ 중요 notices

> **수동 적용 비활성화**: `make apply`는 CI/CD를 통한 배포만 허용합니다.
> 프로덕션 변경은 반드시 Pull Request를 통해 검토되어야 합니다.

## 📄 라이선스

이 프로젝트는 라이선스 파일에 명시된 조건에 따라 라이선스가 부여됩니다.