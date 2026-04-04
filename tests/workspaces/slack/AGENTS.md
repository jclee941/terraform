# AGENTS: tests/workspaces/slack — Slack Workspace Tests

## OVERVIEW
Terraform workspace tests for `320-slack` integration configuration.

## STRUCTURE
```
slack/
├── main.tf                # Test workspace configuration
└── .terraform/            # Provider cache
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Webhook tests | `main.tf` | Validate webhook configs |
| Secret tests | `main.tf` | Validate token handling |

## CONVENTIONS
- Mock Slack API
- Test webhook URL validation
- Validate secret injection

## ANTI-PATTERNS
- NEVER use real Slack tokens
- NEVER post to production channels
