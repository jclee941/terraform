# AGENTS: tests/workspaces - Workspace Validation Tests

## OVERVIEW
Workspace-level variable validation tests for standalone stacks using mock providers, remote-state overrides, and negative assertions.

## STRUCTURE
```text
tests/workspaces/
├── cloudflare/                 # Cloudflare workspace validation tests
├── elk/                        # ELK workspace validation tests
├── gcp/                        # GCP workspace validation tests
├── pve/                        # Proxmox workspace validation tests
├── safetywallet/               # SafetyWallet workspace validation tests
├── synology/                   # Synology workspace validation tests
├── traefik/                    # Traefik workspace remote-state tests
```

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Cloudflare workspace validation | `cloudflare/cloudflare_test.tftest.hcl` | Input format/range checks with `expect_failures`. |
| PVE workspace validation | `pve/pve_test.tftest.hcl` | Endpoint/token/node/network/VMID range/SSH key validation with `override_module` for secrets. |
| ELK workspace validation | `elk/elk_test.tftest.hcl` | Data view and index pattern validation with mock ES provider. |
| Traefik workspace validation | `traefik/traefik_test.tftest.hcl` | Remote-state consumption plan test (no providers). |
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
cd tests/workspaces/pve && terraform init -backend=false && terraform test
cd tests/workspaces/cloudflare && terraform test -filter=cloudflare_test.tftest.hcl
```
