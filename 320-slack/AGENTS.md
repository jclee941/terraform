# AGENTS: 320-slack — Slack Integration (PLANNED)

> **Status**: PLANNED — NOT YET IMPLEMENTED  
> **Tier**: Independent (300-tier external)  
> **Apply Order**: Any — parallel with 300-cloudflare, 301-github, 400-gcp

## OVERVIEW

Planned Slack workspace automation workspace for managing Slack resources via Terraform. This workspace is reserved for Slack channel management, webhook configuration, and workflow automation but has not been implemented yet.

**Current State**: Directory does not exist. Only test scaffolding and provider references are prepared.

## PLANNED STRUCTURE

```
320-slack/
├── main.tf              # Slack provider + resources
├── variables.tf         # Input variables
├── outputs.tf           # Outputs
├── versions.tf          # Provider constraints (pablovarela/slack ~> 1.2)
├── onepassword.tf       # Secret lookup via shared module
└── AGENTS.md            # This file
```

## PREPARED INTEGRATIONS

| Component | Status | Location |
|-----------|--------|----------|
| 1Password secrets | ✅ Prepared | `"slack"` in `required_items` (line 36) |
| Provider cache | ✅ Confirmed | `pablovarela/slack` v1.2.2 in test cache |
| Test scaffolding | ⚠️ Placeholder | `tests/workspaces/slack/` — stub test only |
| Module references | ✅ Listed | `modules/shared/AGENTS.md` documents as consumer |

## INTENDED RESOURCES (Inference)

Based on provider capabilities and monorepo patterns:
- Slack channels (public/private)
- Incoming webhooks
- Slack app manifests
- Workflow automation triggers
- Channel membership management

## CONVENTIONS (To Follow)

- Use `pablovarela/slack` provider (~> 1.2)
- Bot token via `module.onepassword_secrets.secrets["slack_bot_token"]`
- Follow Independent tier patterns from `300-cloudflare/`
- No Proxmox dependencies — pure SaaS integration

## ANTI-PATTERNS

- **DO NOT** create until Slack workspace requirements are defined
- **NEVER** use real bot tokens in tests or local development
- **NEVER** post to production channels from automated tests
- **DO NOT** manage user DMs or private conversations via automation

## NOTES

- Referenced in root `AGENTS.md` as part of Independent tier
- Provider confirmed via test cache: `registry.terraform.io/pablovarela/slack/1.2.2/`
- Would integrate with existing n8n (110) and archon (108) workflows

## NEXT STEPS TO IMPLEMENT

1. Create `320-slack/` directory
2. Add `pablovarela/slack` provider to `versions.tf`
3. Define required Slack resources (channels, webhooks)
4. Wire up `onepassword-secrets` module for bot token
5. Add real tests to `tests/workspaces/slack/`
6. Configure CI job following `300-cloudflare` pattern

## RELATED WORKSPACES

| Workspace | Purpose | Connection |
|-----------|---------|------------|
| 110-n8n | Workflow automation | Could trigger Slack notifications |
| 108-archon | AI knowledge management | Could post alerts to Slack |
| 320-slack | (this) | Central Slack resource management |
