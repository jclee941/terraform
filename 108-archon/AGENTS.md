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
├── sources.yml              # Knowledge base URL manifest
├── scripts/
│   └── sync-sources.sh      # Crawl automation script
├── templates/               # Config templates (rendered by Terraform)
├── terraform/               # Standalone TF workspace (main.tf, variables.tf)
└── tf-configs/              # TF-rendered configs (DO NOT hand-edit)
```

## WHERE TO LOOK

| Task                      | Location                                      |
| ------------------------- | --------------------------------------------- |
| Service ports/IP          | `100-pve/envs/prod/hosts.tf` (archon entry)   |
| LXC provisioning          | `terraform/main.tf` (standalone workspace)    |
| Docker compose            | `docker-compose.yml`                          |
| Environment vars          | `.env.example`, `templates/.env.tftpl`        |
| Archon workflow policy    | `~/.config/opencode/rules/archon-workflow.md` |
| Knowledge source manifest | `sources.yml`                                 |
| Crawl automation          | `scripts/sync-sources.sh`                     |

## PORTS

| Port | Service                             | Container     |
| ---- | ----------------------------------- | ------------- |
| 3737 | Archon Frontend (UI)                | archon-ui     |
| 8181 | Archon Server (FastAPI + Socket.IO) | archon-server |
| 8051 | Archon MCP Server                   | archon-mcp    |
| 8052 | Archon Agents                       | archon-agents |

## DOCKER PROFILES

| Profile       | Containers                                          | Notes                          |
| ------------- | --------------------------------------------------- | ------------------------------ |
| (default)     | archon-server, archon-mcp, archon-ui, archon-agents | 4 containers, always running   |
| `work-orders` | archon-agent-work-orders                            | Opt-in, not running by default |

## CONVENTIONS

- App-config workspace; LXC lifecycle owned by 100-pve/main.tf
- Uses `terraform_remote_state.infra` for host IP/VMID resolution from 100-pve
- Secrets via 1Password (`homelab/archon`) rendered into `.env`
- LLM/embedding config managed via Archon UI → Supabase `archon_settings` table (not env vars)
- Embedding model: `nomic-embed-text:latest` (768-dim) on Ollama at `192.168.50.109:11434`
- Supported LLM providers: openai, google, openrouter, ollama only (no minimax, anthropic, etc.)

## KNOWLEDGE BASE AUTOMATION

### Architecture

Archon has **no native scheduler**. The `update_frequency` field in crawl requests is stored as metadata only — nothing consumes it for automatic re-crawling. All automation is external.

### Components

- **`sources.yml`** — Declarative manifest of documentation URLs to crawl. Each entry has `url`, `tags[]`, `knowledge_type`, `max_depth`, `enabled` flag.
- **`scripts/sync-sources.sh`** — Reads `sources.yml`, compares against existing Archon sources, crawls new/missing ones via REST API. Polls `/api/crawl-progress/{id}` until completion.

### REST API (crawl-related)

| Endpoint                            | Method | Purpose                                                                         |
| ----------------------------------- | ------ | ------------------------------------------------------------------------------- |
| `/api/knowledge-items/crawl`        | POST   | Start crawl (`{url, tags[], knowledge_type, max_depth, extract_code_examples}`) |
| `/api/knowledge-items/{id}/refresh` | POST   | Re-crawl existing source                                                        |
| `/api/crawl-progress/{id}`          | GET    | Poll crawl status (`{status, progress, totalPages, processedPages}`)            |
| `/api/knowledge-items/sources`      | GET    | List all sources                                                                |
| `/api/knowledge-items`              | GET    | List with pagination (`?page&per_page&search`)                                  |

### Usage

```bash
# Preview what would be crawled (no changes)
bash scripts/sync-sources.sh --dry-run

# Crawl all enabled sources not yet in Archon
bash scripts/sync-sources.sh

# Crawl only sources tagged "infrastructure"
bash scripts/sync-sources.sh --tag infrastructure

# Force re-crawl of all sources (even existing)
bash scripts/sync-sources.sh --force
```

### Crawl performance

- Crawling is slow due to LLM summarization on 109-ollama (qwen3:1.7b).
- A single documentation site (30-40 pages) takes 10-30 minutes.
- Script timeout per source: 600 seconds (configurable in script).
- Run during off-peak hours or one tag at a time to avoid overloading Ollama.

### Adding new sources

1. Add entry to `sources.yml` with `url`, `tags`, `knowledge_type`, `max_depth`.
2. Run `bash scripts/sync-sources.sh --dry-run` to verify.
3. Run `bash scripts/sync-sources.sh` to crawl.
4. Verify in Archon UI (archon.jclee.me) or via MCP `rag_search_knowledge_base`.

## DISK MANAGEMENT

- Root filesystem: 20GB LVM volume
- Primary consumers: Docker images (~14GB) + build cache (up to ~10GB)
- `/opt/archon/` source is ~10MB
- Maintenance: `docker builder prune -f` reclaims build cache (3–6GB typical)
- Warning threshold: 80% usage — prune build cache if exceeded

## ENVIRONMENT NOTES

- `GITHUB_PAT_TOKEN`: Optional. Warning logged on restart if unset. Not required for core RAG/MCP functionality.
- All required secrets use `op://` 1Password references in `.env.tftpl`

## ANTI-PATTERNS

- **NO** manual docker-compose edits in `tf-configs/` — edit `templates/` instead
- **NO** Docker socket mounting (CVE-2025-9074, CVSS 9.3)
- **NO** hardcoded Supabase credentials — use 1Password or .env template
- **NO** UI changes to LXC resources (managed by Terraform)
- **NO** manual edits to `archon_settings` in Supabase — use Archon UI
- **NO** reliance on `update_frequency` for auto-refresh — use `sync-sources.sh` or cron

## DEPENDENCIES

- **Upstream**: 107-supabase (vector storage, auth, database), 109-ollama (LLM + embedding inference at `192.168.50.109:11434`)
- **Downstream**: 112-mcphub (MCP integration via port 8051)

## TROUBLESHOOTING

| Symptom                          | Cause                                    | Fix                                               |
| -------------------------------- | ---------------------------------------- | ------------------------------------------------- |
| Crawl pipeline stalls            | Zombie processes in archon-server        | `docker compose restart archon-server`            |
| Embedding failures               | Ollama unreachable or model not loaded   | Verify `curl 192.168.50.109:11434/api/embeddings` |
| Settings reset on restart        | Not a bug — settings persist in Supabase | Verify via `archon_settings` table                |
| Disk usage >80%                  | Docker build cache accumulation          | `docker builder prune -f`                         |
| GITHUB_PAT_TOKEN warning         | Env var unset                            | Non-critical, ignore or set token                 |
| Crawl timeout in script          | Ollama too slow or site too large        | Increase timeout in script or reduce `max_depth`  |
| sync-sources.sh "already exists" | Source URL already crawled               | Use `--force` to re-crawl                         |
