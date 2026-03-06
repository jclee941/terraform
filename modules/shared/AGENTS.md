# AGENTS: modules/shared

## OVERVIEW
Reusable utility modules shared across multiple infrastructure stacks (Proxmox, Cloudflare, etc.). Provides standardized implementations for common patterns like secret management.

## STRUCTURE
```
modules/shared/
├── onepassword-secrets/   # 1Password secret retrieval via service account
├── BUILD.bazel
├── OWNERS
└── AGENTS.md
```

## WHERE TO LOOK
| Task | Module | Notes |
|------|--------|-------|
| **Retrieve Secrets** | `onepassword-secrets` | Uses `1Password/onepassword` provider with `section_map` access pattern. Outputs `secrets` (sensitive, 42 keys) + `metadata` (non-sensitive, 13 keys). |
| **Module Interface** | `onepassword-secrets/variables.tf`, `onepassword-secrets/outputs.tf` | Input/output contract for all consuming workspaces. |
| **Provider wiring** | `onepassword-secrets/main.tf` | Data lookups and secret mapping logic. |
| **Parent module policy** | `../AGENTS.md` | Shared module governance and boundaries. |
| **Primary consumers** | `../../100-pve/AGENTS.md`, `../../104-grafana/AGENTS.md`, `../../105-elk/AGENTS.md`, `../../215-synology/AGENTS.md`, `../../300-cloudflare/AGENTS.md`, `../../301-github/AGENTS.md`, `../../320-slack/AGENTS.md` | Workspace-level usage patterns for secret retrieval. |

## CONVENTIONS
- **Provider-Agnostic**: Logic here must NOT depend on specific infrastructure providers (Proxmox/AWS/Cloudflare) unless strictly necessary.
- **Output-First**: Designed to output values for consumption by other modules.
- **Auth**: Uses `OP_CONNECT_TOKEN` and `OP_CONNECT_HOST` environment variables (Connect Server on LXC 112, port 8090). Provider falls back to these when `op_service_account_token` is empty.

## NOTES
- Keep this scope focused on reusable secret access logic only.
- See sibling module family map in `../proxmox/AGENTS.md` for provisioning-layer modules.
- See root governance in `../AGENTS.md` before introducing new shared modules.

## ANTI-PATTERNS
- **NO Resource Creation**: These modules generally *read* data rather than *create* resources.
- **NO Hardcoded References**: 1Password vault UUID must be passed as variables.
