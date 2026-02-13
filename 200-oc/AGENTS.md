# 200-OC (OPENCODE DEV ENVIRONMENT)

## OVERVIEW
Primary GPU-accelerated development VM (RTX 5070 Ti) dedicated to LLM research and OpenCode configuration engineering. It serves as the staging ground for agentic workflows and the source for the homelab's unified configuration pipeline.

## STRUCTURE
```
200-oc/
├── config/             # System-level configs (cloud-init, systemd)
├── opencode/           # Configuration Generation Pipeline
│   ├── gen/            # Logic scripts (config.py, generate.py)
│   ├── templates/      # Jinja2 templates for 9 agents/8 categories
│   ├── generated/      # OUTPUT: Rendered variants (anti, claude, copilot)
│   └── rules/          # Context-specific agent behavior rules
└── scripts/            # VM maintenance and GPU diagnostic tools
```

## WHERE TO LOOK
| Component | Location | Purpose |
|-----------|----------|---------|
| **Core Config** | `opencode/gen/config.py` | SoT for agent roles and model mappings |
| **Generator** | `opencode/gen/generate.py` | Assembler for the 3 variant outputs |
| **GPU Setup** | `config/cloud-init.yaml` | NVIDIA driver and CUDA configuration |
| **Agent Rules** | `opencode/rules/` | Behavior guidelines injected into sessions |

## CONVENTIONS
- **3 Variants**: 
    - `anti`: Full Antigravity/Google3 integration (default).
    - `claude`: Vanilla Anthropic integration for pure-reasoning tasks.
    - `copilot`: Hybrid variant optimized for VS Code/IDE extensions.
- **Model Selection**: Agents (9 total) are mapped to models in `config.py` using a priority-based fallback system (Thinking > Ultra > Pro).
- **Absolute Paths**: All paths in generated configurations must be absolute, referencing `/home/jclee/` on VM 200.

## ANTI-PATTERNS
- **NO manual `generated/` edits**: Never modify files under `opencode/generated/` directly; they are clobbered by the generation pipeline.
- **NO relative symlinks**: Symlinks for `opencode.jsonc` must use absolute targets to prevent breakage across shell environments.
- **NO local agent config**: Do not edit `~/.config/opencode/` manually; use the pipeline to deploy changes from this repository.
- **NO GPU over-allocation**: Local inference must respect the VRAM limits (16GB) of the RTX 5070 Ti.

