# 112-MCPHUB — Unified AI & Workflow Hub

## OVERVIEW
Unified Model Context Protocol (MCP) management and workflow automation hub. Consolidates multi-provider AI tools (172+ tools) and local infrastructure automation (n8n). Provides a web-based management UI via mcphub.jclee.me.

## ARCHITECTURE
**Hybrid Implementation:**
- **Stdio Servers:** 9 servers run via `npx` directly inside the `mcphub` container (e.g., `sqlite`, `terraform`, `grafana`).
- **SSE Sidecars:** 2 local proxies (`proxmox`, `playwright`) run in dedicated containers to handle long-running or resource-intensive tasks, avoiding pino crashes and isolation issues.
- **SSE External:** `cf-docs` proxied directly to Cloudflare via external SSE.
- **Workflow Engine:** n8n runs as a sidecar for service-to-service automation and incident routing.

## WHERE TO LOOK
- `templates/`: SSoT for configuration templates (`mcp_settings.json.tftpl`, `docker-compose.yml.tftpl`).
- `n8n-workflows/`: JSON definitions for critical automation (GitHub issue sync, error pipelines).
- `Dockerfile.*`: Specialized sidecar builds for SSE proxies.
- `config/filebeat.yml`: Log shipping configuration with strict `max_bytes` size caps to prevent memory leaks.

## CONVENTIONS
- **SSE Migration:** Transition servers from stdio to SSE sidecars if they require native dependencies or exhibit high latency.
- **Port Mapping:** SSE sidecars use the `8050-8060` range for unified discovery.
- **Secrets:** All API keys and tokens must be injected via `.env` file (managed via Vault Agent).

## ANTI-PATTERNS
- **NO manual Docker edits:** Never `docker exec` to change internal configs; always update `templates/` and re-apply via Terraform.
- **NO stdio for heavy tools:** Avoid running browsers or large database drivers as stdio inside the main hub container.
- **NO unmanaged workflows:** Every n8n workflow must have a corresponding JSON export in `n8n-workflows/`.
- **NO direct secrets in templates:** Use env var placeholders for all sensitive tokens.
