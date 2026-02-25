# AGENTS: tests/workspaces - Workspace Validation Tests

## OVERVIEW
Workspace-level variable validation tests for standalone stacks (`100-pve`, `300-cloudflare`, `301-github`, `320-slack`) using mock providers and negative assertions.

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Cloudflare workspace validation | `cloudflare/cloudflare_test.tftest.hcl` | Input format/range checks with `expect_failures`. |
| GitHub workspace validation | `301-github/tests/github_test.tftest.hcl` | Owner/webhook/policy validation. Tests live in-workspace due to `import.tf` root-module constraint. |
| PVE workspace validation | `pve/pve_test.tftest.hcl` | Endpoint/token/node/network/VMID range/SSH key validation with `override_module` for secrets. |
| Slack workspace validation | `slack/slack_test.tftest.hcl` | Bot token format validation with `expect_failures`. |

## CONVENTIONS
- Keep all tests `plan`-only and provider-mocked.
- Keep each invalid input case isolated to one validation target.
- Keep override data explicit for remote state and data-source dependencies.

## ANTI-PATTERNS
- Do not introduce live API dependencies in workspace validation tests.
- Do not rely on broad assertions when exact `expect_failures` targets are available.
