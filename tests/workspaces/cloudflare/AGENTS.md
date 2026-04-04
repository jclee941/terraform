# AGENTS: tests/workspaces/cloudflare — Cloudflare Workspace Tests

## OVERVIEW
Terraform workspace tests for `300-cloudflare` DNS and Workers.

## STRUCTURE
```
cloudflare/
├── main.tf                # Test workspace configuration
└── .terraform/            # Provider cache
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| DNS tests | `main.tf` | Validate record syntax |
| Worker tests | `main.tf` | Validate Worker scripts |

## CONVENTIONS
- Use Cloudflare provider in mock mode
- Test record validation
- Validate Worker JavaScript

## ANTI-PATTERNS
- NEVER make real DNS changes in tests
- NEVER deploy Workers to production
