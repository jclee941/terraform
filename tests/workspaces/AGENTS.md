# AGENTS: tests/workspaces - Workspace Validation Tests

## OVERVIEW
Workspace-level variable validation tests for standalone stacks using mock providers, remote-state overrides, and negative assertions.

## STRUCTURE
```text
tests/workspaces/
├── cloudflare/                 # Migration docs for production-root tests
├── elk/                        # ELK workspace validation tests
├── gcp/                        # GCP workspace validation tests
├── pve/                        # Migration docs for production-root tests
├── safetywallet/               # SafetyWallet workspace validation tests
├── synology/                   # Synology workspace validation tests
```

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Cloudflare workspace validation | `../../300-cloudflare/terraform/tests/cloudflare_test.tftest.hcl` | Production-root DNS and retired-ingress checks. |
| PVE workspace validation | `../../100-pve/terraform/tests/pve_test.tftest.hcl` | Production-root validation and PBS command contracts. |
| ELK workspace validation | `elk/elk_test.tftest.hcl` | Data view and index pattern validation with mock ES provider. |
| GCP workspace validation | `gcp/main.tftest.hcl` | GCP workspace validation with mocked provider behavior. |
| SafetyWallet workspace validation | `safetywallet/main.tftest.hcl` | Reserved external-service workspace checks. |
| Synology workspace validation | `synology/main.tftest.hcl` | Flat workspace validation checks. |

## CONVENTIONS
- Keep all tests `plan`-only and provider-mocked.
- Keep each invalid input case isolated to one validation target.
- Keep override data explicit for remote state and data-source dependencies.

## ANTI-PATTERNS
- Do not introduce live API dependencies in workspace validation tests.
- Do not rely on broad assertions when exact `expect_failures` targets are available.

## COMMANDS
```bash
make test-workspace
terraform -chdir=100-pve/terraform init -backend=false && terraform -chdir=100-pve/terraform test -filter=tests/pve_test.tftest.hcl
terraform -chdir=300-cloudflare/terraform init -backend=false && terraform -chdir=300-cloudflare/terraform test -filter=tests/cloudflare_test.tftest.hcl
```
