# PROJECT KNOWLEDGE BASE

**Generated:** 2026-03-30

## OVERVIEW

MCP-based n8n workflow management agent migrated into the terraform monorepo as `114-cliproxy`. Bun + TypeScript. Exposes the n8n REST API as MCP tools, consumed via an interactive CLI REPL or an OpenAI-compatible HTTP proxy.

## STRUCTURE

```text
./
├── src/
│   ├── config.ts        # env config: n8n, server, proxy, model
│   ├── index.ts         # CLI REPL entry — OpenCode SDK v2 + readline
│   ├── serve.ts         # OpenAI-compatible proxy — Bun.serve at :3001
│   ├── mcp/
│   │   ├── index.ts     # MCP stdio entry point
│   │   └── server.ts    # n8n tools via Zod schemas
│   └── n8n/
│       ├── client.ts    # Typed HTTP client wrapping n8n REST API
│       └── types.ts     # Full n8n API type definitions
├── .env                 # local secrets only, gitignored
├── package.json
└── tsconfig.json
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add/modify MCP tools | `src/mcp/server.ts` | Zod schemas define tool args; each tool calls `src/n8n/client.ts` |
| Add n8n API endpoints | `src/n8n/client.ts` + `src/n8n/types.ts` | Add types first, then client method |
| Change n8n connection | `src/config.ts` | `n8n.baseUrl`, `n8n.apiKey` from env |
| Modify CLI behavior | `src/index.ts` | System prompt at `N8N_SYSTEM_PROMPT`, readline loop |
| Modify proxy behavior | `src/serve.ts` | OpenAI chat completions adapter |
| Change ports/hosts | `src/config.ts` | `server.port` and `proxy.port` |
| Run as standalone MCP | `src/mcp/index.ts` | stdio transport |

## CONVENTIONS

- ESM imports with `.js` extension for local modules.
- Bun runs TypeScript directly; no committed build artifacts.
- Keep secrets out of git.
- Keep changes scoped to this workspace unless wiring into Terraform deployment is explicitly requested.

## ANTI-PATTERNS

- Never commit `.env`.
- Never use `as any` or `@ts-ignore`.
- Never hand-edit generated Terraform configs elsewhere in the monorepo from this workspace.

## COMMANDS

```bash
bun install
bun run start
bun run serve
bun run mcp
```
