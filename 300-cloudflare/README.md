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
│   ├── collect.go            # 로컬 .env/.tfvars에서 시크릿 값 수집 (Go)
│   ├── sync.go               # 수집된 값을 타겟 스토어에 주입 (Go)
│   ├── audit.go              # 시크릿 존재 여부 검증
│   └── generate-bindings.go  # wrangler.toml/jsonc 바인딩 생성
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
go run scripts/collect.go --dry-run

# 실행 (secret-values.tfvars 생성)
go run scripts/collect.go
```

### Terraform 적용

```bash
cd terraform
terraform plan -var-file=secret-values.tfvars
terraform apply -var-file=secret-values.tfvars
```

### 감사

```bash
go run scripts/audit.go               # 모든 타겟 검증
go run scripts/audit.go --help         # 사용법
```

### Worker 바인딩 생성

```bash
go run scripts/generate-bindings.go                # TOML (기본)
go run scripts/generate-bindings.go --format jsonc  # JSON with comments
go run scripts/generate-bindings.go --out wrangler.toml
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
2. `go run scripts/collect.go` 재실행 → `terraform apply`

## 보안

- `secrets.yaml`에는 **값이 저장되지 않음** (메타데이터만)
- `secret-values.tfvars`는 `.gitignore`에 포함
- `.env` 파일은 `.gitignore`에 포함
- Terraform state에 민감 값 포함 → **remote backend 권장**

<!-- BEGIN_TF_DOCS -->


## Requirements

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.0 |
| <a name="requirement_github"></a> [github](#requirement\_github) | ~> 6.6 |
| <a name="requirement_onepassword"></a> [onepassword](#requirement\_onepassword) | ~> 3.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.12 |

## Providers

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 5.18.0 |
| <a name="provider_cloudflare.apikey"></a> [cloudflare.apikey](#provider\_cloudflare.apikey) | 5.18.0 |
| <a name="provider_github"></a> [github](#provider\_github) | 6.11.1 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.8.1 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_time"></a> [time](#provider\_time) | 0.13.1 |

## Resources

## Resources

| Name | Type |
|------|------|
| [cloudflare_dns_record.homelab](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_dns_record.logstash_ingest](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_dns_record.tcp_services](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_logpush_job.worker_traces](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/logpush_job) | resource |
| [cloudflare_r2_bucket.synology_cache](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/r2_bucket) | resource |
| [cloudflare_ruleset.waf_custom](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/ruleset) | resource |
| [cloudflare_workers_route.synology_proxy](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/workers_route) | resource |
| [cloudflare_zero_trust_access_application.homelab](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_access_application) | resource |
| [cloudflare_zero_trust_access_application.logstash_ingest](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_access_application) | resource |
| [cloudflare_zero_trust_access_application.synology](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_access_application) | resource |
| [cloudflare_zero_trust_access_application.tcp_services](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_access_application) | resource |
| [cloudflare_zero_trust_access_identity_provider.google](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_access_identity_provider) | resource |
| [cloudflare_zero_trust_access_identity_provider.otp](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_access_identity_provider) | resource |
| [cloudflare_zero_trust_access_policy.synology_email](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_access_policy) | resource |
| [cloudflare_zero_trust_access_service_token.logpush](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_access_service_token) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared.homelab](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared.jclee](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared.synology](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared_config.homelab](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared_config) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared_config.synology](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared_config) | resource |
| [github_actions_secret.managed](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_secret) | resource |
| [random_password.homelab_tunnel_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.jclee_tunnel_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.tunnel_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [terraform_data.cf_secrets_store](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.cf_store_secret_sync](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.validate_credentials](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [time_rotating.service_token_rotation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/rotating) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared_token.homelab](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/zero_trust_tunnel_cloudflared_token) | data source |
| [cloudflare_zero_trust_tunnel_cloudflared_token.jclee](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/zero_trust_tunnel_cloudflared_token) | data source |
| [cloudflare_zero_trust_tunnel_cloudflared_token.synology](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/zero_trust_tunnel_cloudflared_token) | data source |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_allowed_emails"></a> [access\_allowed\_emails](#input\_access\_allowed\_emails) | List of email addresses allowed through CF Access | `list(string)` | n/a | yes |
| <a name="input_synology_domain"></a> [synology\_domain](#input\_synology\_domain) | Domain/subdomain for Synology proxy (e.g., nas.jclee.me) | `string` | n/a | yes |
| <a name="input_cloudflare_account_id"></a> [cloudflare\_account\_id](#input\_cloudflare\_account\_id) | Cloudflare account ID (optional if provided via 1Password) | `string` | `""` | no |
| <a name="input_cloudflare_api_key"></a> [cloudflare\_api\_key](#input\_cloudflare\_api\_key) | Cloudflare Global API key (fallback when API token is unavailable) | `string` | `""` | no |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token (preferred for scoped access; optional if provided via 1Password) | `string` | `""` | no |
| <a name="input_cloudflare_email"></a> [cloudflare\_email](#input\_cloudflare\_email) | Cloudflare account email (used with API key fallback) | `string` | `""` | no |
| <a name="input_cloudflare_secrets_store_id"></a> [cloudflare\_secrets\_store\_id](#input\_cloudflare\_secrets\_store\_id) | Existing Cloudflare Secrets Store ID | `string` | `"88dc5de305594f08aeb9bc04dad2f8cf"` | no |
| <a name="input_cloudflare_zone_id"></a> [cloudflare\_zone\_id](#input\_cloudflare\_zone\_id) | Cloudflare zone ID for DNS records and Workers routes (optional if provided via 1Password) | `string` | `""` | no |
| <a name="input_elk_ip"></a> [elk\_ip](#input\_elk\_ip) | ELK stack IP address (VMID 105) | `string` | `"192.168.50.105"` | no |
| <a name="input_enable_cf_store_sync"></a> [enable\_cf\_store\_sync](#input\_enable\_cf\_store\_sync) | Enable local-exec wrangler sync for CF Secrets Store beta workflow | `bool` | `false` | no |
| <a name="input_enable_worker_route"></a> [enable\_worker\_route](#input\_enable\_worker\_route) | Enable Workers route (set to true after Worker is deployed via wrangler) | `bool` | `false` | no |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | GitHub organization/user owner | `string` | `"qws941"` | no |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | GitHub token with actions secret write permissions (optional if provided via 1Password) | `string` | `""` | no |
| <a name="input_google_oauth_client_id"></a> [google\_oauth\_client\_id](#input\_google\_oauth\_client\_id) | Google OAuth 2.0 Client ID for CF Access IdP (optional if provided via 1Password) | `string` | `""` | no |
| <a name="input_google_oauth_client_secret"></a> [google\_oauth\_client\_secret](#input\_google\_oauth\_client\_secret) | Google OAuth 2.0 Client Secret for CF Access IdP (optional if provided via 1Password) | `string` | `""` | no |
| <a name="input_homelab_domain"></a> [homelab\_domain](#input\_homelab\_domain) | Base domain for homelab services | `string` | `"jclee.me"` | no |
| <a name="input_homelab_public_ip"></a> [homelab\_public\_ip](#input\_homelab\_public\_ip) | Public IP address of homelab network for CF Access internal bypass | `string` | `null` | no |
| <a name="input_jclee_dev_ip"></a> [jclee\_dev\_ip](#input\_jclee\_dev\_ip) | JCLee development workstation IP address (VMID 200) | `string` | `"192.168.50.200"` | no |
| <a name="input_jclee_ip"></a> [jclee\_ip](#input\_jclee\_ip) | JCLee workstation IP address (physical PC, host ID 80) | `string` | `"192.168.50.80"` | no |
| <a name="input_onepassword_vault_name"></a> [onepassword\_vault\_name](#input\_onepassword\_vault\_name) | 1Password vault name for secret lookups | `string` | `"homelab"` | no |
| <a name="input_secret_values"></a> [secret\_values](#input\_secret\_values) | Runtime secret values map, keyed by secret name (never commit) | `map(string)` | `{}` | no |
| <a name="input_synology_nas_ip"></a> [synology\_nas\_ip](#input\_synology\_nas\_ip) | Synology NAS IP address on local network | `string` | `"192.168.50.215"` | no |
| <a name="input_synology_nas_port"></a> [synology\_nas\_port](#input\_synology\_nas\_port) | Synology DSM HTTP port | `number` | `5000` | no |
| <a name="input_youtube_ip"></a> [youtube\_ip](#input\_youtube\_ip) | YouTube media server IP address (VMID 220) | `string` | `"192.168.50.220"` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_application_id"></a> [access\_application\_id](#output\_access\_application\_id) | Cloudflare Access application ID for Synology |
| <a name="output_homelab_access_applications"></a> [homelab\_access\_applications](#output\_homelab\_access\_applications) | Cloudflare Access applications for restricted services |
| <a name="output_homelab_dns_records"></a> [homelab\_dns\_records](#output\_homelab\_dns\_records) | DNS records created for homelab services |
| <a name="output_homelab_tunnel_id"></a> [homelab\_tunnel\_id](#output\_homelab\_tunnel\_id) | Cloudflare Tunnel ID for homelab services |
| <a name="output_homelab_tunnel_token"></a> [homelab\_tunnel\_token](#output\_homelab\_tunnel\_token) | Cloudflare Tunnel token for homelab cloudflared connector |
| <a name="output_jclee_tunnel_id"></a> [jclee\_tunnel\_id](#output\_jclee\_tunnel\_id) | Cloudflare Tunnel ID for JCLee workstation |
| <a name="output_jclee_tunnel_token"></a> [jclee\_tunnel\_token](#output\_jclee\_tunnel\_token) | Cloudflare Tunnel token for JCLee cloudflared connector |
| <a name="output_managed_github_repos"></a> [managed\_github\_repos](#output\_managed\_github\_repos) | GitHub repositories receiving managed Actions secrets |
| <a name="output_r2_bucket_name"></a> [r2\_bucket\_name](#output\_r2\_bucket\_name) | R2 bucket name used for Synology cache |
| <a name="output_secrets_store_id"></a> [secrets\_store\_id](#output\_secrets\_store\_id) | Cloudflare Secrets Store ID used by this configuration |
| <a name="output_synology_domain"></a> [synology\_domain](#output\_synology\_domain) | Synology domain protected by Cloudflare Access |
| <a name="output_total_secrets_count"></a> [total\_secrets\_count](#output\_total\_secrets\_count) | Total number of secrets in inventory |
| <a name="output_tunnel_id"></a> [tunnel\_id](#output\_tunnel\_id) | Cloudflare Tunnel ID for Synology NAS |
| <a name="output_tunnel_token"></a> [tunnel\_token](#output\_tunnel\_token) | Cloudflare Tunnel token for cloudflared runtime |

<!-- END_TF_DOCS -->
