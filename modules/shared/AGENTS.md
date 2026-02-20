# modules/shared — Cross-Stack Shared Modules

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
| **Retrieve Secrets** | `onepassword-secrets` | Uses `1Password/onepassword` provider with `section_map` access pattern. Outputs `secrets` (sensitive, 31 keys) + `metadata` (non-sensitive, 8 keys). |

## CONVENTIONS
- **Provider-Agnostic**: Logic here must NOT depend on specific infrastructure providers (Proxmox/AWS/Cloudflare) unless strictly necessary.
- **Output-First**: Designed to output values for consumption by other modules.
- **Auth**: Uses `OP_SERVICE_ACCOUNT_TOKEN` environment variable.

## ANTI-PATTERNS
- **NO Resource Creation**: These modules generally *read* data rather than *create* resources.
- **NO Hardcoded References**: 1Password vault UUID must be passed as variables.
