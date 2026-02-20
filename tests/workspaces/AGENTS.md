# AGENTS: tests/workspaces - Workspace Validation Tests

## OVERVIEW
Workspace-level variable validation tests for standalone stacks (`300-cloudflare`, `301-github`) using mock providers and negative assertions.

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Cloudflare workspace validation | `cloudflare_test.tftest.hcl` | Input format/range checks with `expect_failures`. |
| GitHub workspace validation | `github_test.tftest.hcl` | Owner/webhook/policy validation and override data setup. |

## CONVENTIONS
- Keep all tests `plan`-only and provider-mocked.
- Keep each invalid input case isolated to one validation target.
- Keep override data explicit for remote state and data-source dependencies.

## ANTI-PATTERNS
- Do not introduce live API dependencies in workspace validation tests.
- Do not rely on broad assertions when exact `expect_failures` targets are available.
