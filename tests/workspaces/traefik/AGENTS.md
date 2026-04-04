# AGENTS: tests/workspaces/traefik — Traefik Workspace Tests

## OVERVIEW
Terraform workspace tests for `102-traefik` routing configuration.

## STRUCTURE
```
traefik/
├── main.tf                # Test workspace configuration
└── .terraform/            # Provider cache
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Route tests | `main.tf` | Validate dynamic routes |
| Middleware tests | `main.tf` | Auth, rate limit, headers |

## CONVENTIONS
- Test template rendering
- Validate route syntax
- Mock host inventory

## ANTI-PATTERNS
- NEVER test with real certs in CI
- NEVER expose test services
