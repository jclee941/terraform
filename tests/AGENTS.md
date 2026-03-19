# AGENTS: tests — Terraform Test Harness

## OVERVIEW
Shared test workspace for Terraform-native test execution (`.tftest.hcl`) across modules, integration flows, and standalone workspaces.

## STRUCTURE
```
tests/
├── modules/proxmox/      # Module unit tests + fixtures
├── integration/          # Cross-module pipeline tests
└── workspaces/           # Workspace-level variable validation tests
    ├── archon/          # Archon workspace remote-state tests
    ├── cloudflare/      # Cloudflare workspace validation
    ├── elk/             # ELK workspace validation
    ├── grafana/         # Grafana workspace validation
    ├── pve/             # PVE workspace validation
    ├── slack/           # Slack workspace validation
    └── traefik/         # Traefik workspace remote-state tests
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Module behavior checks | `tests/modules/` | Module test subtrees (proxmox, shared). |
| Proxmox module tests | `tests/modules/proxmox/AGENTS.md` | Proxmox module test suites and fixtures. |
| Shared module tests | `tests/modules/shared/AGENTS.md` | onepassword-secrets mock-provider contracts. |
| Pipeline integration checks | `tests/integration/AGENTS.md` | Config renderer and hosts-map end-to-end strategy. |
| Workspace validation checks | `tests/workspaces/AGENTS.md` | Standalone workspace variable-validation strategy. |
| Specific workspace tests | `tests/workspaces/{archon,cloudflare,elk,grafana,pve,slack,traefik}/` | Per-workspace `*_test.tftest.hcl` + mock `main.tf`. |

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
