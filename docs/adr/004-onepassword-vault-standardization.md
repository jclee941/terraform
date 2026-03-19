# ADR-004: 1Password Vault Item Standardization

**Status:** Accepted
**Date:** 2026-03-08

## Context

An audit of the homelab 1Password vault (22 items) revealed structural inconsistencies that cause silent bugs and maintenance friction:

1. **Silent data access bugs** — 3 items (ssh_key, n8n, mcphub) store secrets in unnamed sections while module code reads `.password` (root field), which returns empty strings. These secrets silently fail at runtime.
2. **Phantom output references** — `outputs.tf` references 3 fields (`tunnel_token`, `google_oauth_client_id`, `google_oauth_client_secret`) in the cloudflare item that do not exist in the vault, producing empty strings.
3. **No naming convention** — Item names mix lowercase (`grafana`) and titlecase (`Runway`, `Google`). Section names vary between use-case (`Bot`, `MCP Tokens`), generic (`Secrets`, `Passwords`), and unnamed.
4. **Category misuse** — Items like `heygen` and `Runway` use PASSWORD category when API_CREDENTIAL is correct.
5. **Monolithic items** — The `Google` item conflates GCP, YouTube, and Vertex AI credentials in a freeform `notes` field with no structured sections.
6. **Duplicate items** — Two `slack` items exist; one is YouTube-specific with tag `youtube` but same name.
7. **Placeholder values** — 7 secrets across 3 items (archon, exa, splunk) contain literal `placeholder` strings that pass Terraform validation but fail at runtime.
8. **Inconsistent workspace patterns** — File naming (`secrets.tf` vs `onepassword.tf`), check blocks (only 100-pve), and comment styles vary across 8 consumer workspaces.

## Decision

### Item Naming Convention

- All item names MUST be lowercase kebab-case (`[a-z0-9-]+`).
- Item name = service identity (e.g., `grafana`, `slack-mcp`, `slack-youtube`).
- Disambiguate by function, not by vault tag (rename duplicate `slack` → `slack-youtube`).
- Split monolithic items by provider: `Google` → `gcp` + `youtube`.

### Section Naming Convention

- Section names MUST describe the credential domain, not the data type.
- Prefer: `Credentials`, `API Keys`, `Database`, `Connection`, `Bot`, `Dashboard`.
- Avoid: generic names like `Secrets`, `Passwords`, `Login`.
- Every field MUST live in a named section — unnamed sections are forbidden.

### Category Rules

| Credential Type | 1Password Category | Access Pattern |
|---|---|---|
| Single API key/token (no username) | API_CREDENTIAL | `.credential` |
| Username + password pair | PASSWORD | section field map |
| Multi-field service credentials | PASSWORD | section field map |

### Access Pattern Standardization

All secrets MUST be accessible via one of two patterns:

1. **Section field map**: `section_map["SectionName"].field_map["field_name"].value`
2. **API_CREDENTIAL**: `.credential` (top-level, for single-token items only)

The `.password` root field access pattern is **prohibited** for new items. Existing items using `.password` MUST migrate fields into named sections.

### Items Requiring Vault Changes

| Item | Action | Detail |
|---|---|---|
| n8n | Move `api_key` from unnamed section → `API Keys` section | Fix silent empty access |
| mcphub | Move `admin_password` from unnamed section → `Credentials` section | Fix silent empty access |
| ssh_key | Move `private_key` from unnamed section → `Keys` section | Fix silent empty access |
| pbs | Remove empty unnamed section field, keep `Login` section | Cleanup |
| safetywallet | Remove empty unnamed section fields | Cleanup |
| heygen | Change category → API_CREDENTIAL, name fields in section | Fix category |
| Runway | Rename → `runway`, change category → API_CREDENTIAL | Fix naming + category |
| Google | Split → `gcp` (structured sections) + `youtube` (structured sections) | Decouple providers |
| slack (duplicate) | Rename → `slack-youtube` | Disambiguate |
| splunk | Mark as deprecated or populate with real values | Resolve placeholder |
| archon | Populate with real API keys or remove from required list | Resolve placeholder |
| exa | Populate with real credential or remove from required list | Resolve placeholder |

### Module Code Fixes

| File | Fix |
|---|---|
| `outputs.tf` | Remove phantom `tunnel_token`, `google_oauth_client_id`, `google_oauth_client_secret` from cloudflare |
| `outputs.tf` | Update ssh_key from `.password` → `section_map["Keys"].field_map["private_key"].value` |
| `outputs.tf` | Update n8n from `.password` → `section_map["API Keys"].field_map["api_key"].value` |
| `outputs.tf` | Update mcphub from `.password` → `section_map["Credentials"].field_map["admin_password"].value` |
| `main.tf` | Add `youtube`, `gcp` to item lists after vault split |

### Workspace Standardization

1. **File naming**: All consumer workspaces use `onepassword.tf` (rename 100-pve `secrets.tf` → `onepassword.tf`).
2. **Check blocks**: Every consumer workspace MUST have check blocks validating the secrets it consumes.
3. **Comment style**: Use `# ===== Section =====` header format consistently.
4. **Module invocation**: Standardize to `module "onepassword_secrets"` with `vault_name` parameter.

### Documentation Updates

- `docs/secret-management.md`: Update item inventory, access patterns, workspace table, item count.
- `AGENTS.md`: Update service inventory if item count changes.

## Alternatives Considered

1. **Keep `.password` pattern** — Avoid vault restructuring. Rejected: silent bugs are unacceptable; empty strings pass Terraform validation but fail at runtime.
2. **Single section per item** — Flatten all fields into one section. Rejected: loses logical grouping for multi-concern items (e.g., supabase has Keys + Database + Dashboard).
3. **Automated migration script** — Write Go script to restructure vault. Rejected: 1Password CLI item editing has limitations with section management; manual restructuring is safer for a one-time operation of 12 items.
4. **Custom data source wrapper** — Abstract access patterns behind a Terraform module that handles both `.password` and section lookups. Rejected: adds complexity; better to fix the source of truth.

## Consequences

- One-time manual vault restructuring required (~12 items, ~30 minutes).
- Module `outputs.tf` changes require `terraform plan` verification across all 8 consumer workspaces.
- All future items follow the naming/section/category conventions without ambiguity.
- Silent empty-string bugs eliminated for ssh_key, n8n, mcphub.
- Phantom output references removed — `terraform plan` shows clean diff.
- Check blocks catch missing/empty secrets at plan time across all workspaces.
- `secret-management.md` becomes accurate single source of truth for vault structure.
