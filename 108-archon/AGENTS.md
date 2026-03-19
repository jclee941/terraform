# AGENTS: 108-archon

## OVERVIEW

Archon AI Knowledge Management system with MCP server integration. Provides AI-powered knowledge crawling, indexing, and retrieval with Supabase vector storage backend.

- **VMID**: 108
- **IP**: 192.168.50.108
- **Type**: LXC Container
- **Domain**: archon.jclee.me (via Traefik)

## WHERE TO LOOK

| Task                      | Location                                    |
| ------------------------- | ------------------------------------------- |
| LXC provisioning          | `terraform/main.tf` (standalone workspace)  |
| Docker compose            | `docker-compose.yml`                        |
| Environment vars          | `.env.example`, `templates/.env.tftpl`      |
| Knowledge source manifest | `sources.yml`                               |
| Crawl automation          | `scripts/sync-sources.go`                   |
| SPA doc injection         | `scripts/inject-docs.go`                    |

## PORTS

| Port | Service              | Container     |
| ---- | -------------------- | ------------- |
| 3737 | Frontend (UI)        | archon-ui     |
| 8181 | Server (FastAPI)     | archon-server |
| 8051 | MCP Server           | archon-mcp    |
| 8052 | Agents               | archon-agents |

## CONVENTIONS

- App-config workspace; LXC lifecycle owned by 100-pve/main.tf
- Secrets via 1Password (`homelab/archon`) rendered into `.env`
- LLM/embedding config via Archon UI → Supabase `archon_settings` table (not env vars)
- Embedding: `nomic-embed-text:latest` (768-dim) on Ollama at 192.168.50.215:11434
- Supported providers: openai, google, openrouter, ollama, anthropic, grok
- No native scheduler — `update_frequency` is metadata only; use `sync-sources.go`
- `GITHUB_PAT_TOKEN` optional — warning on restart if unset, non-critical
- Disk: 20GB root, Docker ~14GB. `docker builder prune -f` at >80% usage
- Default profile: 4 containers. `work-orders` profile is opt-in.

## KNOWLEDGE BASE AUTOMATION

- **`sources.yml`** — Declarative URL manifest (`url`, `tags[]`, `knowledge_type`, `max_depth`, `enabled`, `ingest_method`)
- **`sync-sources.go`** — Compares manifest against Archon, crawls new/missing via REST API
- **`inject-docs.go`** — Direct Supabase injection for SPA sites that Archon's crawler cannot handle (fetches HTML, chunks, embeds via Ollama, inserts with L2-normalized vectors)
- Crawling is slow (LLM summarization on Ollama): 30-40 page site takes 10-30 min
- Sources with `ingest_method: inject` cannot use `sync-sources.go` — use `inject-docs.go` instead
- Adding crawlable sources: edit `sources.yml` → `go run scripts/sync-sources.go --dry-run` → `go run scripts/sync-sources.go`
- Adding SPA sources: edit `sources.yml` → `SUPABASE_SERVICE_KEY=... go run scripts/inject-docs.go --sitemap-url <url> --url-pattern '<regex>' --tag <tags>`
- inject-docs.go flags: `--sitemap-url` (discover pages), `--url-pattern` (filter regex), `--tag` (CSV tags), `--source-id`, `--force` (delete+re-inject), `--dry-run`

## ANTI-PATTERNS

- **NO** manual docker-compose edits in `tf-configs/` — edit `templates/` instead
- **NO** Docker socket mounting (CVE-2025-9074)
- **NO** hardcoded Supabase credentials — use 1Password or .env template
- **NO** manual edits to `archon_settings` in Supabase — use Archon UI

## DEPENDENCIES

- **Upstream**: 107-supabase (vector storage), 215-synology/ollama (LLM + embedding)
- **Downstream**: 112-mcphub (MCP integration via port 8051)

## TROUBLESHOOTING

| Symptom               | Fix                                                          |
| --------------------- | ------------------------------------------------------------ |
| Crawl pipeline stalls | `docker compose restart archon-server`                       |
| Embedding failures    | Verify Ollama: `curl 192.168.50.215:11434/api/embeddings`    |
| Disk usage >80%       | `docker builder prune -f`                                    |
| Crawl timeout         | Increase script timeout or reduce `max_depth`                |
| SPA site not crawled  | Use `inject-docs.go` — Archon crawler cannot follow SPA links |
