# AGENTS: 200-oc/opencode/gen - OpenCode Generator Internals

## OVERVIEW
Generator internals for producing variant config outputs from `config.py` source-of-truth and model-ID resolution helpers.

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Variant assembly flow | `generate.py` | Build/write pipeline for `opencode.jsonc`, `oh-my-opencode.json`, `antigravity.json`. |
| Source-of-truth data | `config.py` | Agents, categories, MCP catalog ingestion, plugin list, variants. |
| Model ID mapping | `model_id.py` | Provider/model expansion logic used by generator. |
| Generator tests | `model_id_test.py` | ID mapping regression coverage. |

## CONVENTIONS
- Keep `config.py` as the single editable source for model/category/plugin mappings.
- Keep generated output contract stable across all variants.
- Keep catalog-derived values pulled from `112-mcphub/mcp_servers.json`.

## ANTI-PATTERNS
- Do not hand-edit files under `opencode/generated/`.
- Do not commit runtime account/signature caches.
- Do not patch generated JSON directly to change agent behavior.
