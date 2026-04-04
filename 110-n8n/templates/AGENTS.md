# AGENTS: 110-n8n/templates — n8n Workflow Automation

## OVERVIEW
Terraform templates for n8n deployment (LXC 110). Self-hosted workflow automation platform.

## STRUCTURE
```
templates/
├── docker-compose.yml.tftpl  # n8n + dependencies
└── .env.tftpl                # Environment config
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Stack | `docker-compose.yml.tftpl` | n8n, Postgres, Redis |
| Config | `.env.tftpl` | DB credentials, encryption key, base URL |

## CONVENTIONS
- Webhook URL: `https://n8n.jclee.me/webhook/`
- Basic auth enabled by default
- Workflows exported to JSON for backup

## ANTI-PATTERNS
- NEVER commit encryption key — use 1Password
- NEVER expose webhook endpoints without auth
- NEVER store workflow credentials in UI — use credentials feature
