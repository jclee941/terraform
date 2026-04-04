# AGENTS: tests/workspaces/pve — PVE Workspace Tests

## OVERVIEW
Terraform workspace tests for `100-pve` infrastructure provisioning.

## STRUCTURE
```
pve/
├── main.tf                # Test workspace configuration
└── .terraform/            # Provider cache
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Test setup | `main.tf` | Test-specific workspace vars |
| Assertions | `tests/` parent | Module-level assertions |

## CONVENTIONS
- Use `terraform test` framework
- Mock providers where possible
- Test plan, not apply

## ANTI-PATTERNS
- NEVER run real applies in tests
- NEVER test against production state
