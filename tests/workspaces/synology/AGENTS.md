# AGENTS: tests/workspaces/synology — Synology Workspace Tests

## OVERVIEW
Terraform workspace tests for `215-synology` NAS configuration.

## STRUCTURE
```
synology/
├── main.tf                # Test workspace configuration
└── .terraform/            # Provider cache
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Config tests | `main.tf` | Validate Synology settings |
| Network tests | `main.tf` | IP and port validation |

## CONVENTIONS
- Mock Synology API
- Test configuration syntax
- Validate network parameters

## ANTI-PATTERNS
- NEVER modify production NAS in tests
- NEVER test destructive operations
