# AGENTS: 108-archon

## OVERVIEW
Archon AI Knowledge Management system with MCP server integration. Provides AI-powered knowledge crawling, indexing, and retrieval with Supabase vector storage backend.

- **VMID**: 108
- **IP**: 192.168.50.108
- **Type**: LXC Container
- **Domain**: archon.jclee.me (via Traefik)

## STRUCTURE
```
108-archon/
├── BUILD.bazel              # Bazel governance
├── OWNERS                   # Ownership
├── AGENTS.md                # This file
├── README.md                # Service documentation
├── DEPLOYMENT-DECISION.md   # Deployment architecture decisions
├── docker-compose.yml       # Docker service definitions
├── .env.example             # Environment variable template
├── templates/               # Config templates (rendered by Terraform)
├── terraform/               # Standalone TF workspace (main.tf, variables.tf)
└── tf-configs/              # TF-rendered configs (DO NOT hand-edit)
```

## WHERE TO LOOK
| Task | Location |
|------|----------|
| Service ports/IP | `100-pve/envs/prod/hosts.tf` (archon entry) |
| LXC provisioning | `terraform/main.tf` (standalone workspace) |
| Docker compose | `docker-compose.yml` |
| Environment vars | `.env.example`, `templates/.env.tftpl` |

## PORTS
| Port | Service |
|------|---------|
| 3737 | Archon Frontend (UI) |
| 8181 | Archon Server (FastAPI + Socket.IO) |
| 8051 | Archon MCP Server |

## CONVENTIONS
- App-config workspace; LXC lifecycle owned by 100-pve/main.tf
- Uses `terraform_remote_state.infra` for host IP/VMID resolution from 100-pve
- Secrets via 1Password (`homelab/archon`) rendered into `.env`
- Docker Compose profiles: default (server+mcp+frontend), `agents` (opt-in)
- LLM/embedding config managed via Archon UI → Supabase `archon_settings` table (not env vars)

## ANTI-PATTERNS
- **NO** manual docker-compose edits in `tf-configs/` — edit `templates/` instead
- **NO** Docker socket mounting (CVE-2025-9074, CVSS 9.3)
- **NO** hardcoded Supabase credentials — use 1Password or .env template
- **NO** UI changes to LXC resources (managed by Terraform)

## DEPENDENCIES
- **Upstream**: 107-supabase (vector storage, auth, database), 109-ollama (LLM + embedding inference at `192.168.50.109:11434`)
- **Downstream**: 112-mcphub (MCP integration via port 8051)
