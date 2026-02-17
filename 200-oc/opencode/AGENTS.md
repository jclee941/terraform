# 200-oc/opencode — OpenCode Config Generation Pipeline

**Purpose:** Generates 3 OpenCode config variants (`anti`, `claude`, `copilot`) from a single source of truth.
**Deployed to:** `/home/jclee/.config/opencode/` on VM 200 via Terraform `vm-config` module.

## STRUCTURE
```
opencode/
├── gen/                    # Python generators
│   ├── generate.py         # Main: reads config.py → writes to generated/
│   ├── config.py           # SoT: agents, categories, MCPs, plugins, variants
│   ├── model_id.py         # Model ID resolution (provider → full model string)
│   └── model_id_test.py    # Tests
├── variants/               # Per-variant oh-my-opencode.json overrides
├── generated/              # OUTPUT (do not hand-edit)
│   └── {variant}/          # opencode.jsonc, oh-my-opencode.json, antigravity.json,
│                           # wrapper script, systemd service
├── bin/                    # Launchers: anti, claude, copilot, opencode-sync
├── rules/                  # Agent rules (session-init, cicd-bazel, large-refactor)
├── templates/              # Jinja2: opencode.service.j2, opencode-wrapper.sh.j2
├── systemd/                # 3 service files (opencode-{anti,claude,copilot})
├── opencode.jsonc          # Base config (MCP servers + plugins)
├── antigravity.json        # Auth plugin config
└── supermemory.jsonc        # Supermemory plugin config
```

## PIPELINE
`config.py` (SoT) → `generate.py` → `generated/{variant}/` → Terraform `vm-config` → VM 200

- **config.py**: Defines 9 agents (`AgentSpec`), 8 categories, MCP servers, plugins, variant overrides. Replaces old TF `variables.tf` data.
- **generate.py**: Resolves model IDs via `model_id.py`, renders Jinja2 templates, writes JSON configs + systemd + wrappers.
- **model_id.py**: Maps `(model_name, provider)` → full model ID. Tested via `model_id_test.py`.

## WHERE TO LOOK
| Task | Location |
|------|----------|
| Add/change agent model | `gen/config.py` → `AGENTS` dict |
| Add MCP server | `gen/config.py` → MCP section |
| Add new variant | `variants/{name}/oh-my-opencode.json` + update `config.py` |
| Modify systemd service | `templates/opencode.service.j2` |
| Add agent rule | `rules/{name}.md` |

## COMMANDS
```bash
python3 gen/generate.py                          # Generate all variants
N8N_MCP_API_KEY=xxx python3 gen/generate.py      # With n8n token
python3 -m pytest gen/model_id_test.py           # Run tests
bazel test //200-oc/opencode/...                 # Bazel test
```

## ANTI-PATTERNS
- **NO hand-editing** `generated/` — overwritten by generator.
- **NEVER** commit `antigravity-accounts.json` or `antigravity-signature-cache.json`.
- **NO direct model changes** in `oh-my-opencode.json` — change `gen/config.py` and re-generate.

## NOTES
- Agent mappings change frequently — always check `gen/config.py` for current state.
- `micode` plugin patched: bun-pty→node-pty, bun:sqlite→better-sqlite3.
- `opencode-sync` in `bin/` syncs generated configs to VM 200.
