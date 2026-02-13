# Cloudflare Secrets Management

Terraform + 스크립트 기반 시크릿 중앙 관리 시스템.

## Architecture

```
inventory/secrets.yaml (메타데이터 레지스트리, 값 없음)
         │
         ├─► CF Secrets Store  ── Workers 런타임
         ├─► GitHub Secrets    ── CI/CD (Actions)
         └─► HashiCorp Vault   ── 서버 (홈랩)
```

3개 타겟 스토어에 시크릿을 Terraform으로 선언적 관리하고, 스크립트로 값 주입·감사·바인딩 생성.

## 구조

```
├── inventory/
│   └── secrets.yaml          # 시크릿 메타데이터 레지스트리 (50+ entries)
├── terraform/
│   ├── versions.tf           # Provider 선언 (cloudflare 5.x, github 6.x, vault 4.x)
│   ├── main.tf               # Provider 설정
│   ├── variables.tf          # 입력 변수
│   ├── locals.tf             # secrets.yaml 파싱, 타겟별 분류
│   ├── secrets-store.tf      # CF Secrets Store 리소스
│   ├── github-secrets.tf     # GitHub Actions Secrets 리소스
│   ├── vault-secrets.tf      # Vault KV v2 리소스
│   └── outputs.tf            # 결과 출력
├── scripts/
│   ├── collect.sh            # 로컬 .env/.tfvars에서 시크릿 값 수집
│   ├── sync.sh               # 수집된 값을 타겟 스토어에 주입
│   ├── audit.sh              # 시크릿 존재 여부 검증
│   └── generate-bindings.sh  # wrangler.toml/jsonc 바인딩 생성
├── .env.example              # Terraform 인증 변수 템플릿
└── .gitignore
```

## 사전 요구사항

- Terraform ≥ 1.0
- [yq](https://github.com/mikefarah/yq) v4
- `gh` CLI (GitHub 인증 완료)
- `vault` CLI (Vault 사용 시)

## 설정

```bash
cp .env.example .env
# .env에 실제 인증 정보 입력:
#   CLOUDFLARE_API_TOKEN, CF_ACCOUNT_ID
#   GITHUB_TOKEN
#   VAULT_ADDR, VAULT_TOKEN (선택)

source .env
cd terraform && terraform init
```

## 사용법

### 시크릿 값 수집 (로컬 프로젝트 → tfvars)

```bash
# 드라이런 (미리보기)
scripts/collect.sh --dry-run

# 실행 (secret-values.tfvars 생성)
scripts/collect.sh
```

### Terraform 적용

```bash
cd terraform
terraform plan -var-file=secret-values.tfvars
terraform apply -var-file=secret-values.tfvars
```

### 감사

```bash
scripts/audit.sh               # 모든 타겟 검증
scripts/audit.sh --help         # 사용법
```

### Worker 바인딩 생성

```bash
scripts/generate-bindings.sh                # TOML (기본)
scripts/generate-bindings.sh --format jsonc  # JSON with comments
scripts/generate-bindings.sh --out wrangler.toml
```

## 시크릿 추가

1. `inventory/secrets.yaml`에 메타데이터 추가:
   ```yaml
   - name: NEW_SECRET_NAME
     category: api_keys
     description: "설명"
     projects: [project-name]
     targets: [cf_store, github]
     rotate_days: 90
     sensitive: true
   ```
2. `scripts/collect.sh` 재실행 → `terraform apply`

## 보안

- `secrets.yaml`에는 **값이 저장되지 않음** (메타데이터만)
- `secret-values.tfvars`는 `.gitignore`에 포함
- `.env` 파일은 `.gitignore`에 포함
- Terraform state에 민감 값 포함 → **remote backend 권장**
