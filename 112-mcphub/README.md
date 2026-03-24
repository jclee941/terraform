# 112-mcphub

MCPhub MCP Server Hub for the jclee.me homelab. Aggregates and proxies Model Context Protocol servers.

## Services

- **MCPhub** (3000) — MCP server gateway, catalog UI, and stdio/SSE proxy for 13 MCP servers
- **1Password Connect** (8090) — Vault access API consumed by op-mcp-server sidecar
- **Proxmox MCP** (8055) — SSE sidecar for Proxmox VE management
- **Playwright MCP** (8056) — SSE sidecar for browser automation

## Access

- MCPhub UI: https://mcphub.jclee.me

## Management

Managed by Terraform via `100-pve/main.tf`. See `AGENTS.md` for conventions.
