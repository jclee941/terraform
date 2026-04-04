# AGENTS: tests/workspaces/archon — Archon Workspace Tests

## OVERVIEW
Terraform workspace tests for `108-archon` MCP server deployment.

## STRUCTURE
```
archon/
├── main.tf                # Test workspace configuration
└── .terraform/            # Provider cache
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Config tests | `main.tf` | Validate Archon YAML configs |
| MCP tests | `main.tf` | Server connectivity |

## CONVENTIONS
- Test YAML syntax
- Validate MCP server definitions
- Mock LLM responses

## ANTI-PATTERNS
- NEVER use real API keys in tests
- NEVER test against production Archon
