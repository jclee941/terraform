# AGENTS: modules/shared/onepassword-secrets - Secret Retrieval Contract

## OVERVIEW
Data-source module that reads homelab secrets from 1Password and exposes a stable output map for template rendering.

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Vault/item lookup | `main.tf` | `onepassword_vault` + service-specific `onepassword_item` data sources. |
| Input defaults | `variables.tf` | `vault_name` contract and default. |
| Output schema | `outputs.tf` | `secrets` (sensitive) and `metadata` (non-sensitive) maps. |
| Item schema details | `README.md` | Required `secrets` section + field map access pattern. |

## CONVENTIONS
- Keep output key names stable; many templates consume this flat map.
- Keep all lookups wrapped with `try(..., "")` to support terraform tests with mocks.
- Keep provider auth via `OP_CONNECT_TOKEN` and `OP_CONNECT_HOST` (Connect Server on LXC 112, port 8090). Provider falls back to these when `op_service_account_token` is empty.

## ANTI-PATTERNS
- Do not create infrastructure resources here; data-source reads only.
- Do not hardcode vault UUIDs; use vault name input lookup.
- Do not rename output keys without coordinated template and test updates.
