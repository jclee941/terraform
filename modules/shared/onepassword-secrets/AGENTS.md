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
- Provider auth config inherited from parent scope; see `modules/shared/AGENTS.md`.

## ANTI-PATTERNS
- Do not create infrastructure resources here; data-source reads only.
- Do not hardcode vault UUIDs; use vault name input lookup.
- Do not rename output keys without coordinated template and test updates.
