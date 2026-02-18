# 112-MCPHUB — Unified AI & Workflow Hub

## OVERVIEW
Unified Model Context Protocol (MCP) management and workflow automation hub. Consolidates multi-provider AI tools (25 servers) via single gateway. All MCP servers run on MCPHub — no local MCP clients. Provides a web-based management UI via mcphub.jclee.me.

## ARCHITECTURE
**SSoT Catalog:** `mcp_servers.json` is the Single Source of Truth for ALL MCP server definitions across the monorepo. Both Terraform (`mcp_settings.json.tftpl`) and OpenCode gen pipeline (`200-oc/opencode/gen/config.py`) consume this catalog.

**Server Locations:**
- **Hub (21):** ALL servers run on MCPHub VM 112. Stdio servers auto-exposed as SSE by MCPHub. SSE sidecars run in dedicated containers. Ports 5678, 8054-8078.
- **External (4):** Third-party SSE endpoints (`cf-docs`, `cf-observability`, `cf-radar`, `cf-workers`).

**Transport Types:**
- **Stdio:** 18 servers run via `npx`/`uvx` inside MCPHub container, auto-proxied to SSE.
- **SSE Sidecars:** 2 servers (`proxmox`, `playwright`) in dedicated Docker containers.
- **HTTP:** 1 server (`n8n`) with Bearer auth at `:5678/mcp-server/http`.
- **Workflow Engine:** n8n runs as a sidecar for service-to-service automation and incident routing.

## WHERE TO LOOK
- `mcp_servers.json`: **SSoT** — Canonical catalog of ALL MCP servers (hub/external).
- `templates/`: Configuration templates rendered by Terraform (`mcp_settings.json.tftpl`, `docker-compose.yml.tftpl`).
- `validate_mcps.py`: Validation script for catalog schema, port uniqueness, secret detection.
- `n8n-workflows/`: JSON definitions for critical automation (GitHub issue sync, error pipelines).
- `Dockerfile.*`: Specialized sidecar builds for SSE proxies.
- `config/filebeat.yml`: Log shipping configuration with strict `max_bytes` size caps to prevent memory leaks.

## CONVENTIONS
- **SSoT Catalog:** Add/modify MCP servers ONLY in `mcp_servers.json`. Downstream consumers auto-sync.
- **SSE Migration:** Transition servers from stdio to SSE sidecars if they require native dependencies or exhibit high latency.
- **Port Mapping:** Hub servers use ports 8054-8078. n8n uses 5678.
- **Secrets:** All API keys and tokens must be injected via `.env` file (managed via Vault Agent). Use `${}` placeholders in catalog, NEVER real tokens.

## ANTI-PATTERNS
- **NO manual Docker edits:** Never `docker exec` to change internal configs; always update `templates/` and re-apply via Terraform.
- **NO stdio for heavy tools:** Avoid running browsers or large database drivers as stdio inside the main hub container.
- **NO unmanaged workflows:** Every n8n workflow must have a corresponding JSON export in `n8n-workflows/`.
- **NO direct secrets in templates:** Use env var placeholders for all sensitive tokens.
