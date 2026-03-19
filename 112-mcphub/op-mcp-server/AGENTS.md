# AGENTS: 112-mcphub/op-mcp-server

## OVERVIEW

Standalone Node.js stdio MCP sidecar that exposes 1Password Connect operations to MCP clients. This scope owns the package runtime contract, not the broader `mcp_servers.json` catalog.

## STRUCTURE

```text
112-mcphub/op-mcp-server/
├── index.mjs          # MCP server implementation and tool handlers
├── package.json       # Package metadata, bin entry, dependency intent
├── package-lock.json  # Resolved dependency graph
└── AGENTS.md
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| MCP server runtime | `index.mjs` | Stdio transport, tool schema, 1Password Connect fetch helpers. |
| Package contract | `package.json` | ESM module type, `op-mcp-server` bin mapping, start script. |
| Dependency resolution | `package-lock.json` | Lockstep dependency state for the sidecar image/runtime. |
| Catalog wiring | `../AGENTS.md` | Parent scope for `mcp_servers.json` and template integration. |

## CONVENTIONS

- Runtime requires `OP_CONNECT_HOST` and `OP_CONNECT_TOKEN`; the process exits fast when either is missing.
- Keep this package ESM-only and stdio-based; the transport contract is `StdioServerTransport`, not an HTTP daemon.
- Preserve the MCP response shape in `index.mjs`: text content plus structured JSON for tool responses.
- Keep `package.json` and `package-lock.json` in sync whenever dependencies change.

## ANTI-PATTERNS

- Do not hardcode 1Password endpoints, tokens, or secret values in source.
- Do not move catalog or template rules into this package; those stay in `112-mcphub/`.
- Do not change required env var names or the stdio entrypoint without updating the sidecar wiring in parent templates and catalog references.
- Do not treat this as a generic web server package; it is a single-purpose MCP sidecar.
