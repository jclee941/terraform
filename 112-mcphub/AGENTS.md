# 112-MCPHUB — Unified MCP Gateway

## OVERVIEW
MCP service catalog and gateway scope for VM 112. Primary ownership is server catalog integrity (`mcp_servers.json`), template rendering inputs, and MCP sidecar container assets.

## ARCHITECTURE
- **SSoT Catalog:** `mcp_servers.json` is the canonical MCP server registry.
- **Consumers:** `100-pve/main.tf` parses the catalog for Terraform rendering; `200-oc/opencode/gen/config.py` consumes the same catalog for OpenCode generation.
- **Runtime Split:** Catalog defines 9 active servers (9 `stdio`). Docker sidecars (`Dockerfile.proxmox`, `Dockerfile.playwright`) are infra assets, not catalog entries.

## GENERATED VS SOURCE
- **Source-editable:** `mcp_servers.json`, `templates/*.tftpl`, `Dockerfile.*`, `validate_mcps.py`, `n8n-workflows/*.json`.
- **Generated/reference-only:** rendered files under service `tf-configs/` and deployment outputs under `100-pve/configs/`; `config/filebeat.yml` is reference-only.
- **Edit Rule:** change templates/catalog, then re-render through Terraform workflows.

## WHERE TO LOOK
- `mcp_servers.json`: SSoT catalog (location, transport, command/url, port, env placeholders).
- `validate_mcps.py`: schema + port uniqueness + secret-pattern validation.
- `templates/mcp_settings.json.tftpl`: OpenCode MCP settings render target.
- `templates/docker-compose.yml.tftpl`: mcphub + sidecar runtime template.
- `Dockerfile.proxmox`, `Dockerfile.playwright`: sidecar build definitions.
- `n8n-workflows/`: exported automation workflows that must match runtime state.

## CONVENTIONS
- Modify MCP inventory in `mcp_servers.json` only; do not split server truth across files.
- Keep secrets as `${ENV_VAR}` placeholders in catalog/templates.
- Keep port assignments unique for hub transports; validate with `python3 validate_mcps.py`.
- Treat the Archon MCP endpoint as catalog data, not inline Terraform literals.

## ANTI-PATTERNS
- Never hand-edit rendered deployment outputs (`tf-configs/`, `100-pve/configs/...`).
- Never inject plaintext tokens/keys in catalog, templates, or workflow JSON.
- Never mutate running containers via ad-hoc `docker exec` config changes.
- Never add n8n runtime workflows without exporting committed JSON counterparts.

## COMMANDS
```bash
python3 112-mcphub/validate_mcps.py
make plan SVC=pve
make apply SVC=pve
```
