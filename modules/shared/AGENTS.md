# modules/shared — Cross-Stack Shared Modules

## OVERVIEW
Reusable utility modules shared across multiple infrastructure stacks (Proxmox, Cloudflare, etc.). Provides standardized implementations for common patterns like secret management.

## STRUCTURE
```
modules/shared/
├── vault-secrets/    # HashiCorp Vault KV v2 secret retrieval
└── vault-agent/      # Vault Agent AppRole auto-auth + template engine
```

## WHERE TO LOOK
| Task | Module | Notes |
|------|--------|-------|
| **Retrieve Secrets** | `vault-secrets` | Wraps `vault_generic_secret` for KV v2. |
| **Runtime Auth** | `vault-agent` | AppRole auto-auth config for runtime secret injection. |
| **Runtime Auth** | `vault-agent` | AppRole auto-auth config for runtime secret injection. |

## CONVENTIONS
- **Provider-Agnostic**: Logic here must NOT depend on specific infrastructure providers (Proxmox/AWS/Cloudflare) unless strictly necessary.
- **Output-First**: Designed to output values for consumption by other modules.

## ANTI-PATTERNS
- **NO Resource Creation**: These modules generally *read* data rather than *create* resources.
- **NO Hardcoded Paths**: Vault paths must be passed as variables.
