# AGENTS: 108-archon/templates — Archon Service Templates

## OVERVIEW
Terraform templates for Archon deployment (LXC 108). Archon MCP server and agent orchestration.

## STRUCTURE
```
templates/
├── docker-compose.yml.tftpl  # Archon services stack
├── config.yml.tftpl          # Archon server config
└── agent-config.yml.tftpl    # Agent work order config
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Stack | `docker-compose.yml.tftpl` | Server, MCP, agent workers |
| Server config | `config.yml.tftpl` | LLM providers, MCP servers |
| Agent config | `agent-config.yml.tftpl` | Work order queue settings |

## CONVENTIONS
- Uses Docker Compose for multi-service deployment
- Server API on port 8181, MCP on 8051
- Connects to Ollama on LXC 109:11434

## ANTI-PATTERNS
- NEVER commit LLM API keys
- NEVER use default admin credentials
- NEVER expose MCP port without auth
