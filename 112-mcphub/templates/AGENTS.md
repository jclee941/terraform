# AGENTS: 112-mcphub/templates — MCPHub Service Templates

## OVERVIEW
Terraform templates for MCPHub VM (112) deployment.

## STRUCTURE
```
templates/
├── .env.tftpl                         # Runtime environment
├── docker-compose-op-connect.yml.tftpl # 1Password Connect sidecar
├── docker-compose.yml.tftpl            # MCPHub stack
├── filebeat.yml.tftpl                  # Log forwarding
└── mcp_settings.json.tftpl             # MCP client settings
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Runtime env | `.env.tftpl` | Placeholder-driven environment file. |
| Service stack | `docker-compose.yml.tftpl` | MCPHub runtime stack. |
| 1Password Connect | `docker-compose-op-connect.yml.tftpl` | Secret sidecar stack. |
| MCP client settings | `mcp_settings.json.tftpl` | Generated MCP client config. |
| Log forwarding | `filebeat.yml.tftpl` | Logs to ELK. |

## CONVENTIONS
- Keep secrets as placeholders; values come from 1Password/env at render time.
- Keep `mcp_servers.json` as the catalog SSoT; templates consume it indirectly through Terraform.
- Render through `100-pve` pipelines rather than hand-editing runtime files.

## ANTI-PATTERNS
- NEVER commit cloud-init passwords
- NEVER use default SSH keys
