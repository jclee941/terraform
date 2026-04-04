# AGENTS: 112-mcphub/config — MCPHub Configuration

## OVERVIEW
Configuration for MCPHub (VM 112). MCP server aggregation and management.

## STRUCTURE
```
config/
├── mcphub.yml             # MCP server registry
└── servers/               # Per-server configs
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Server registry | `mcphub.yml` | List of MCP servers and capabilities |
| Individual configs | `servers/*.yml` | Server-specific settings |

## CONVENTIONS
- Use YAML for all configs
- Server URLs from `module.hosts`
- Credentials via 1Password

## ANTI-PATTERNS
- NEVER commit API keys or tokens
- NEVER use hardcoded server IPs
