# AGENTS: tests/workspaces/elk — ELK Workspace Tests

## OVERVIEW
Terraform workspace tests for `105-elk` Logstash pipeline and ES config.

## STRUCTURE
```
elk/
├── main.tf                # Test workspace configuration
└── .terraform/            # Provider cache
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Pipeline tests | `main.tf` | Validate Logstash config syntax |
| Grok tests | `main.tf` | Pattern matching validation |

## CONVENTIONS
- Use Logstash configtest
- Validate grok patterns
- Test pipeline execution

## ANTI-PATTERNS
- NEVER use real logs with PII in tests
- NEVER test against production ES
