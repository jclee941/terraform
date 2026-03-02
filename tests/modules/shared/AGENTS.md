# AGENTS: tests/modules/shared — Shared Module Tests

## OVERVIEW
Terraform-native tests for shared modules. Current scope validates `onepassword-secrets` behavior with mocked provider data.

## STRUCTURE
```text
tests/modules/shared/
├── main.tf                              # Test provider requirements
├── onepassword_secrets_test.tftest.hcl  # Shared module contract tests
├── README.md                            # Shared-module test notes
├── BUILD.bazel
└── OWNERS
```

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Provider mock setup | `onepassword_secrets_test.tftest.hcl` | `mock_provider "onepassword"` + overrides. |
| Test provider versions | `main.tf` | Keep onepassword provider constraints aligned with module. |
| Bazel ownership/governance | `BUILD.bazel`, `OWNERS` | Keep Google3-style governance intact. |

## CONVENTIONS
- Use `terraform test` with fully mocked provider responses; no live 1Password dependency.
- Keep override data explicit per item (grafana, proxmox, github, cloudflare, etc.).
- Add both positive and failure-oriented assertions when module behavior changes.
- Keep test names scoped to module contracts, not environment runtime behavior.

## ANTI-PATTERNS
- Do not call live 1Password APIs in default test runs.
- Do not hide missing fields behind weak assertions; use explicit contract checks.
- Do not couple shared module tests to service-specific template logic.
- Do not change fixture keys without updating all override targets.

## COMMANDS
```bash
make test-unit
cd tests/modules/shared && terraform init -backend=false && terraform test
cd tests/modules/shared && terraform test -filter=onepassword_secrets_test.tftest.hcl
```
