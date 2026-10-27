# AGENTS: tests/workspaces/cloudflare — Cloudflare Workspace Tests

## OVERVIEW
Terraform workspace tests for `300-cloudflare` DNS and Workers.

## STRUCTURE
```
300-cloudflare/terraform/tests/
└── cloudflare_test.tftest.hcl    # Production-root test file
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| DNS and retired-ingress tests | `300-cloudflare/terraform/tests/cloudflare_test.tftest.hcl` | Runs in the production root with mocked providers. |

## CONVENTIONS
- Use Cloudflare provider in mock mode
- Test record validation
- Validate Worker JavaScript

## ANTI-PATTERNS
- NEVER make real DNS changes in tests
- NEVER deploy Workers to production

## COMMANDS
```bash
terraform -chdir=300-cloudflare/terraform test -filter=tests/cloudflare_test.tftest.hcl
make test-workspace
```
