# AGENTS: tests/workspaces - Workspace Validation Tests

## OVERVIEW
Workspace-level variable validation tests for standalone stacks (`100-pve`, `300-cloudflare`, `320-slack`) using mock providers and negative assertions.

## STRUCTURE
```text
tests/workspaces/
├── cloudflare/                  # Cloudflare workspace validation tests
├── elk/                         # ELK workspace validation tests
├── grafana/                     # Grafana workspace validation tests
├── pve/                         # Proxmox workspace validation tests
├── slack/                       # Slack workspace validation tests
├── BUILD.bazel
└── OWNERS
```

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Cloudflare workspace validation | `cloudflare/cloudflare_test.tftest.hcl` | Input format/range checks with `expect_failures`. |
| PVE workspace validation | `pve/pve_test.tftest.hcl` | Endpoint/token/node/network/VMID range/SSH key validation with `override_module` for secrets. |
| Slack workspace validation | `slack/slack_test.tftest.hcl` | Bot token format validation with `expect_failures`. |

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
cd tests/workspaces/slack && terraform test -filter=slack_test.tftest.hcl
```
