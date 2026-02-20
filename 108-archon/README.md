# 107-archon: AI Knowledge Management System

## OVERVIEW
Archon is an AI-powered knowledge management system that provides MCP (Model Context Protocol) server capabilities for AI coding assistants like Claude Code, Cursor, and Windsurf. It indexes codebases, documents, and knowledge bases with vector embeddings for intelligent retrieval.

**Upstream**: https://github.com/coleam00/Archon (v0.1.0 beta)

## INFRASTRUCTURE
| Component | Value |
|-----------|-------|
| **VMID** | 107 |
| **IP Address** | 192.168.50.107 |
| **Hostname** | archon |
| **Public URL** | https://archon.jclee.me |
| **Type** | LXC Container (Docker-based) |
| **Resources** | 4 cores, 6 GB RAM, 20 GB disk |
| **OS** | Ubuntu 22.04 |

## ARCHITECTURE
Archon is a microservices stack running via Docker Compose:

### Core Services (Always Running)
1. **archon-ui** (React/Vite)
   - Port: `3737`
   - Purpose: Web UI for configuration and knowledge base management
   - Public access via Traefik: `archon.jclee.me`

2. **archon-server** (FastAPI + SocketIO)
   - Port: `8181`
   - Purpose: Backend API, web crawling, document processing
   - Internal only

3. **archon-mcp** (MCP Protocol Interface)
   - Port: `8051`
   - Purpose: MCP server for AI assistant integration
   - Internal only (accessed by Claude Code, Cursor, etc. via SSH tunnel or direct connection)

### Optional Services (Profiles)
4. **archon-agents** (PydanticAI + Gemini)
   - Port: `8052`
   - Purpose: AI-powered agents for advanced reranking and question answering
   - Profile: `agents`

5. **archon-agent-work-orders** (Work Order System)
   - Port: `8053`
   - Purpose: Automated task creation and tracking
   - Profile: `work-orders`

## DEPENDENCIES
### External Services (Required)
- **Supabase** (PostgreSQL + PGVector): Vector database for embeddings
  - Option 1: Cloud (https://supabase.com/dashboard)
  - Option 2: Self-hosted on separate VMID (TBD)
- **OpenAI API** (optional): For embeddings and chat (can use Gemini/Ollama)

### No Qdrant Required
Archon uses Supabase's PGVector extension instead of Qdrant.

## CONFIGURATION
### Environment Variables (Minimal)
Only Supabase credentials are required in `.env`:
```bash
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGc...
```

All other secrets (OpenAI API, Gemini API, GitHub tokens) are managed via the web UI and stored encrypted in the database.

### Secrets Management
- **Supabase credentials**: Injected via Vault Agent from `vault/archon/supabase`
- **API keys**: Configured via Archon UI (stored in `credentials` table, encrypted)

### Database Migration
Before first run, apply the 1375-line SQL migration to Supabase:
```bash
psql $SUPABASE_URL -f migration/complete_setup.sql
```

This creates:
- PGVector extension
- 8+ tables (codebase_files, embedding_chunks, credentials, etc.)
- Proper indexes and constraints

## NETWORKING
| Port | Service | Exposure | Traefik Route |
|------|---------|----------|---------------|
| 3737 | archon-ui | Public | `archon.jclee.me` → 192.168.50.107:3737 |
| 8181 | archon-server | Internal | N/A |
| 8051 | archon-mcp | Internal | N/A (MCP clients connect directly) |
| 8052 | archon-agents | Internal | Optional |
| 8053 | archon-agent-work-orders | Internal | Optional |

## DEPLOYMENT
### Terraform
- **Module**: Uses `module.lxc` from `terraform/modules/lxc/`
- **Config**: Defined in `107-archon/terraform/main.tf`
- **Sizing**: 4 cores, 6144 MB RAM, 20 GB disk (defined in `terraform/envs/prod/sizing.tf`)
- **Cloud-Init**: Installs Docker + Docker Compose via cloud-init snippet

### Docker Compose
- **File**: `107-archon/docker-compose.yml` (customized from upstream)
- **Profiles**: Default (ui, server, mcp) + optional (`agents`, `work-orders`)
- **Start**: `docker compose up -d`
- **Logs**: `docker compose logs -f`

### Traefik Routing
- **Config**: `102-traefik/tf-configs/routing/archon.yml` (Terraform-rendered)
- **Domain**: `archon.jclee.me` (Cloudflare DNS)
- **SSL**: Let's Encrypt via Traefik

## MONITORING
### Grafana Dashboard
- **Metrics**: Docker container health, resource usage
- **Logs**: Filebeat → Logstash → Elasticsearch (105-elk)
- **Alerts**: Container down, high memory usage

### Health Checks
- UI: `http://192.168.50.107:3737/health`
- Server: `http://192.168.50.107:8181/health`
- MCP: `http://192.168.50.107:8051/health`

## MCP CLIENT INTEGRATION
### Claude Code / Cursor / Windsurf
Add to MCP client settings:
```json
{
  "mcpServers": {
    "archon": {
      "command": "ssh",
      "args": [
        "root@192.168.50.107",
        "docker", "compose", "-f", "/opt/archon/docker-compose.yml",
        "exec", "-T", "archon-mcp", "python", "mcp_server.py"
      ]
    }
  }
}
```

Or use direct TCP connection (if exposed):
```json
{
  "mcpServers": {
    "archon": {
      "url": "http://192.168.50.108:8051/mcp",
      "type": "streamable-http"
    }
  }
}
```

## MAINTENANCE
### Updates
```bash
# Pull latest from upstream
cd /opt/archon
git pull origin stable

# Rebuild and restart
docker compose down
docker compose build --no-cache
docker compose up -d
```

### Backup
- **Database**: Supabase project backups (includes vector embeddings)
- **Configs**: Terraform state (`terraform.tfstate`)
- **Knowledge Base**: Export via Archon UI

### Troubleshooting
| Issue | Solution |
|-------|----------|
| UI not loading | Check `docker compose logs archon-ui` |
| MCP connection failed | Verify port 8051 accessible, check logs |
| Embeddings not working | Verify Supabase connection, check `embedding_chunks` table |
| Slow performance | Check RAM usage (min 6 GB required) |

## SECURITY
### CVE-2025-9074 Mitigation
Archon's default `docker-compose.yml` disables Docker socket mounting. No action required.

### API Key Storage
- API keys stored encrypted in Supabase `credentials` table
- Never commit `.env` files with Supabase credentials
- Use Vault Agent for secret injection

## REFERENCES
- **Setup Video**: https://youtu.be/DMXyDpnzNpY
- **Upstream Repo**: https://github.com/coleam00/Archon
- **MCP Protocol**: https://modelcontextprotocol.io/
- **Supabase**: https://supabase.com/docs

## NOTES
- **Beta Software**: v0.1.0 released Oct 2024, expect bugs
- **Use `stable` branch**: `git checkout stable` before deployment
- **Playwright**: Requires Chromium libraries for web crawling (included in Docker image)
- **PydanticAI**: Optional agents profile requires Gemini API key
