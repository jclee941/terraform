# AGENTS: 112-mcphub/config — MCPHub Configuration

## OVERVIEW
Runtime/reference config helpers for MCPHub (VM 112). Source-of-truth catalog edits belong in `../mcp_servers.json` and templates in `../templates/`.

## STRUCTURE
```
config/
├── filebeat.yml            # Reference/rendered log forwarding config
├── entrypoint-patch.go     # Patch helper source
├── entrypoint-patch        # Built helper artifact
├── patch-placeholder.cjs   # Runtime patch helper
└── patch-sdk-schema.cjs    # Runtime patch helper
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| MCP server registry | `../mcp_servers.json` | Catalog SSoT. |
| Runtime templates | `../templates/AGENTS.md` | Generated environment/settings source. |
| Patch helper source | `entrypoint-patch.go` | Go helper for runtime patching. |
| Log forwarding | `filebeat.yml` | Reference config for ELK shipping. |

## CONVENTIONS
- Keep catalog data out of this directory.
- Keep credentials via 1Password/env placeholders.
- Treat generated/runtime artifacts here as reference unless a runbook says otherwise.

## ANTI-PATTERNS
- NEVER commit API keys or tokens
- NEVER use hardcoded server IPs
