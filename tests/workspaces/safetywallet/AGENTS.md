# AGENTS: tests/workspaces/safetywallet — SafetyWallet Workspace Tests

## OVERVIEW
Terraform workspace tests for `310-safetywallet` infrastructure.

## STRUCTURE
```
safetywallet/
├── main.tf                # Test workspace configuration
└── .terraform/            # Provider cache
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Config tests | `main.tf` | Validate SafetyWallet configs |
| Integration tests | `main.tf` | Service connectivity |

## CONVENTIONS
- Mock external APIs
- Test configuration syntax
- Validate secrets injection

## ANTI-PATTERNS
- NEVER use production credentials
- NEVER make real API calls
