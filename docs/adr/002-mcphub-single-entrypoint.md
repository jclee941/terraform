# ADR-002: MCPHub as Single MCP Entrypoint

**Status:** Accepted
**Date:** 2026-02-14

## Context

AI development tools (OpenCode) required access to 24 MCP servers. Managing individual server configs per client was error-prone and hard to keep in sync.

## Decision

Use MCPHub (VM 112:3000) as a single gateway for all MCP servers:
- Clients configure ONE endpoint: `http://192.168.50.112:3000/mcp`
- All server definitions in `mcp_servers.json` (SSoT)
- Local-only servers (bazel, in-memoria) remain client-side
- StreamableHTTP support (legacy SSE compatibility at the gateway)

## Alternatives Considered

1. **Individual MCP configs per client** — 24 entries to maintain per machine
2. **Docker Compose per server** — No unified discovery/health checks
3. **Nginx reverse proxy** — No MCP-aware routing or server management UI

## Consequences

- Single config change propagates to all clients
- MCPHub UI for server health monitoring
- SSoT pipeline: `mcp_servers.json` → Terraform templates → runtime config
- Sidecar Dockerfiles for servers needing custom environments (Playwright, Proxmox)
- Dependency on VM 112 availability
