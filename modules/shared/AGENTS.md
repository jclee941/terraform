# AGENTS: modules/shared

## OVERVIEW
Reusable utility modules shared across multiple infrastructure stacks (Proxmox, Cloudflare, etc.). Provides standardized implementations for common patterns like secret management.

## STRUCTURE
```
modules/shared/
└── onepassword-secrets/   # 1Password secret retrieval via service account
```

## WHERE TO LOOK
| Task | Module | Notes |
|------|--------|-------|
| **Retrieve Secrets** | `onepassword-secrets` | Uses `1Password/onepassword` provider with `section_map` access pattern. Outputs `secrets` (sensitive, 36 keys) + `metadata` (non-sensitive, 7 keys). |

## CONVENTIONS
- **Provider-Agnostic**: Logic here must NOT depend on specific infrastructure providers (Proxmox/AWS/Cloudflare) unless strictly necessary.
- **Output-First**: Designed to output values for consumption by other modules.
- **Auth**: Uses `OP_CONNECT_TOKEN` and `OP_CONNECT_HOST` environment variables (Connect Server on LXC 112, port 8090). Provider falls back to these when `op_service_account_token` is empty.

## ANTI-PATTERNS
- **NO Resource Creation**: These modules generally *read* data rather than *create* resources.
- **NO Hardcoded References**: 1Password vault UUID must be passed as variables.
