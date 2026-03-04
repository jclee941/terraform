# 112-mcphub

MCPhub MCP Server Hub for the jclee.me homelab. Aggregates and proxies Model Context Protocol servers.

## Services

- **MCPhub** (3000) — MCP server gateway and catalog UI
- **1Password MCP** (8090) — 1Password Connect sidecar
- **n8n** (5678) — Workflow automation

## Access

- MCPhub UI: https://mcphub.jclee.me
- n8n UI: https://n8n.jclee.me

## Management

Managed by Terraform via `100-pve/main.tf`. See `AGENTS.md` for conventions.
