# AGENTS: tests — Terraform Test Harness

## OVERVIEW
Shared test workspace for Terraform-native test execution (`.tftest.hcl`) across modules, integration flows, and standalone workspaces.

## STRUCTURE
```
tests/
├── modules/proxmox/      # Proxmox module unit/rendering tests
├── modules/shared/       # 1Password module contract tests
├── modules/cloudflare/   # Cloudflare tunnel module tests
├── modules/elasticstack/ # ILM/index template module tests
├── integration/          # Cross-module pipeline tests
└── workspaces/           # Workspace validation roots and migration docs
    ├── cloudflare/      # Migration docs; tests live in 300-cloudflare/terraform/tests
    ├── elk/             # ELK workspace validation
    ├── gcp/             # GCP workspace validation
    ├── pve/             # Migration docs; tests live in 100-pve/terraform/tests
    ├── safetywallet/    # SafetyWallet workspace validation
    ├── synology/        # Synology workspace validation
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Module behavior checks | `tests/modules/` | Module test subtrees (proxmox, shared, cloudflare, elasticstack). |
| Proxmox module tests | `tests/modules/proxmox/AGENTS.md` | Proxmox module test suites and fixtures. |
| Shared module tests | `tests/modules/shared/AGENTS.md` | onepassword-secrets mock-provider contracts. |
| Cloudflare module tests | `tests/modules/cloudflare/` | Tunnel module contract checks. |
| Elasticstack module tests | `tests/modules/elasticstack/` | ILM policy and index template checks. |
| Pipeline integration checks | `tests/integration/AGENTS.md` | Config renderer and hosts-map end-to-end strategy. |
| Workspace validation checks | `tests/workspaces/AGENTS.md` | Standalone workspace variable-validation strategy. |
| PVE production-root tests | `100-pve/terraform/tests/` | Provider-mocked, plan-only tests executed against the production root. |
| Cloudflare production-root tests | `300-cloudflare/terraform/tests/` | Provider-mocked, plan-only tests executed against the production root. |
| Other workspace tests | `tests/workspaces/{elk,gcp,safetywallet,synology}/` | Per-workspace `*.tftest.hcl` and fixtures. |

## CONVENTIONS
- Use native `terraform test`; avoid custom runners.
- Keep tests provider-mocked unless explicitly validating live infrastructure.
- Prefer explicit `expect_failures` targets for validation-failure scenarios.
- Keep fixture templates deterministic and path-stable.

## ANTI-PATTERNS
- Do not perform real API calls from test fixtures.
- Do not add service-specific runtime guidance here; keep that in the service/module AGENTS files.
- Do not rely on implicit variable defaults in negative tests.
- Do not put cross-workspace validation scenarios in module tests; use `tests/workspaces/`.
- Do not combine unrelated module contracts in one run block.

## COMMANDS
```bash
make test
make test-unit
make test-integration
terraform test
```

## NOTES
- `make test` runs Proxmox/shared module tests, integration tests, production-root PVE/Cloudflare tests, and selected workspace tests.
