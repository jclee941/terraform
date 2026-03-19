# AGENTS: 310-safetywallet — SafetyWallet Service

> **Status**: template-only

**Tunnel ID:** abd283cf-032a-402b-8c41-5689315bd47b
**Status:** Active (CF tunnel: 310-safetywallet)

## OVERVIEW

SafetyWallet external service. Connected to homelab infrastructure via dedicated Cloudflare tunnel. Not managed by Terraform — reserved workspace for future provider integration.

## STRUCTURE

```
310-safetywallet/
├── AGENTS.md    # This file
└── README.md    # Service documentation
```

## WHERE TO LOOK

| Task                | Location             | Notes                               |
| ------------------- | -------------------- | ----------------------------------- |
| CF tunnel config    | Cloudflare Dashboard | Tunnel: 310-safetywallet (abd283cf) |
| Service integration | TBD                  | Reserved workspace                  |

## CONVENTIONS

- External service (300+ numbering range).
- Cloudflare tunnel provides connectivity.
- Tunnel managed outside Terraform (manual cloudflared connector).

## ANTI-PATTERNS

- Do not store secrets or credentials in this directory.
- Do not hardcode tunnel IDs in other workspaces.
