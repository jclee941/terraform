# AGENTS: 112-mcphub

> **Host**: VM 112 | **IP**: 192.168.50.112 | **Status**: template-only

## OVERVIEW

MCP service catalog and gateway scope for VM 112. Primary ownership is server catalog integrity (`mcp_servers.json`), template rendering inputs, and MCP sidecar container assets.

## ARCHITECTURE

- **SSoT Catalog:** `mcp_servers.json` is the canonical MCP server registry.
- **Consumers:** `100-pve/main.tf` parses the catalog for Terraform rendering. `mcp-health-check.yml` validates port reachability.
- **Runtime Split:** Catalog defines 12 active servers (8 `stdio`, 2 `sse`, 2 `streamable-http`). Docker sidecars (`Dockerfile.proxmox`, `Dockerfile.playwright`) are infra assets, not catalog entries.

## GENERATED VS SOURCE

- **Source-editable:** `mcp_servers.json`, `templates/*.tftpl`, `Dockerfile.*`, `validate_mcps.py`, `op-mcp-server/`.
- **Generated/reference-only:** rendered files under service `tf-configs/` and deployment outputs under `100-pve/configs/`; `config/filebeat.yml` is reference-only.
- **Edit Rule:** change templates/catalog, then re-render through Terraform workflows.

## WHERE TO LOOK

| Task                  | Location                                      | Notes                                            |
| --------------------- | --------------------------------------------- | ------------------------------------------------ |
| MCP server registry   | `mcp_servers.json`                            | SSoT catalog (transport, port, env placeholders) |
| Catalog validation    | `validate_mcps.py`                            | Schema + port uniqueness + secret-pattern checks |
| OpenCode MCP settings | `templates/mcp_settings.json.tftpl`           | Render target for MCP client config              |
| Runtime template      | `templates/docker-compose.yml.tftpl`          | mcphub + sidecar containers                      |
| 1Password MCP sidecar | `op-mcp-server/`                              | Node.js (`index.mjs` + `package.json`)           |
| Sidecar Dockerfiles   | `Dockerfile.proxmox`, `Dockerfile.playwright` | Build definitions                                |
| 1Password MCP sidecar | `op-mcp-server/`                              | Node.js (`index.mjs` + `package.json`)           |
| Sidecar Dockerfiles   | `Dockerfile.proxmox`, `Dockerfile.playwright` | Build definitions                                |
| n8n workflows         | `n8n-workflows/`                              | Exported workflows — must match runtime          |

## CONVENTIONS

- Modify MCP inventory in `mcp_servers.json` only; do not split server truth across files.
- Keep secrets as `${ENV_VAR}` placeholders in catalog/templates.
- Keep port assignments unique for hub transports; validate with `python3 validate_mcps.py`.
- Treat the Archon MCP endpoint as catalog data, not inline Terraform literals.
- Secrets from 1Password (`homelab/mcphub`) via `onepassword-secrets` module. 10 keys including proxmox tokens, admin password, API keys, 1Password Connect token, and proxy credentials.

## ANTI-PATTERNS

- Never hand-edit rendered deployment outputs (`tf-configs/`, `100-pve/configs/...`).
- Never inject plaintext tokens/keys in catalog or templates.
- Never mutate running containers via ad-hoc `docker exec` config changes.
- Never inject plaintext tokens/keys in catalog, templates, or workflow JSON.
- Never mutate running containers via ad-hoc `docker exec` config changes.
- Never add n8n runtime workflows without exporting committed JSON counterparts.

## COMMANDS

```bash
python3 112-mcphub/validate_mcps.py
make plan SVC=pve
# make apply is DISABLED locally — all applies go through CI/CD workflows
```
