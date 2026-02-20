from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .config import (
    AGENTS,
    ANTIGRAVITY,
    CATEGORIES,
    FORMATTER,
    GITHUB_COPILOT_MODELS,
    GOOGLE_MODELS,
    LOCAL_MCP_ENV_OVERRIDES,
    LOCAL_MCPS,
    MCPHUB_URL,
    MCP_TIMEOUT,
    OPENCODE_BASE,
    PLUGINS,
    VARIANTS,
)
from .model_id import resolve_agents, resolve_categories


ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT / "generated"


# -- JSON builders -----------------------------------------------------------


def _build_opencode_json(variant: str, cfg: dict[str, Any]) -> dict[str, Any]:
    # -- MCP servers ----------------------------------------------------------
    mcp: dict[str, Any] = {}

    # MCPHub gateway — single aggregated endpoint for all hub-hosted servers.
    mcp["mcphub"] = {
        "type": "remote",
        "url": MCPHUB_URL,
        "transport": "streamable-http",
        "timeout": MCP_TIMEOUT,
    }

    # Local MCPs (run on OC VM directly).
    for name, mcfg in LOCAL_MCPS.items():
        cmd = [mcfg["command"]] + mcfg.get("args", [])
        entry: dict[str, Any] = {
            "type": "local",
            "command": cmd,
            "timeout": MCP_TIMEOUT,
        }

        # Merge catalog env with OC VM-specific overrides.
        env_base = {
            k: v
            for k, v in (mcfg.get("env") or {}).items()
            if not isinstance(v, str) or not v.startswith("${")
        }
        env_overrides = LOCAL_MCP_ENV_OVERRIDES.get(name, {})
        env = {**env_base, **env_overrides}
        if env:
            entry["environment"] = env

        mcp[name] = entry

    # -- Assemble top-level config -------------------------------------------
    return {
        "$schema": OPENCODE_BASE["$schema"],
        "theme": OPENCODE_BASE["theme"],
        "instructions": OPENCODE_BASE["instructions"],
        "default_agent": OPENCODE_BASE["default_agent"],
        "username": OPENCODE_BASE["username"],
        "plugin": PLUGINS,
        "provider": {
            "google": {"models": GOOGLE_MODELS},
            "github-copilot": {"models": GITHUB_COPILOT_MODELS},
        },
        "mcp": mcp,
        "permission": OPENCODE_BASE["permission"],
        "experimental": OPENCODE_BASE["experimental"],
        "compaction": OPENCODE_BASE["compaction"],
        "small_model": OPENCODE_BASE["small_model"],
        "formatter": FORMATTER,
        "keybinds": OPENCODE_BASE["keybinds"],
    }


def _build_oh_my_opencode_json(variant: str) -> dict[str, Any]:
    """Build oh-my-opencode.json for a variant using resolved model IDs."""
    agents = resolve_agents(variant, AGENTS)
    categories = resolve_categories(variant, CATEGORIES)
    return {
        "$schema": "oh-my-opencode.schema.json",
        "google_auth": False,
        "agents": agents,
        "categories": categories,
    }


def _build_antigravity_json() -> dict[str, Any]:
    return {"$schema": "antigravity.schema.json", **ANTIGRAVITY}



# -- Generator ----------------------------------------------------------------


def _write_json(path: Path, data: dict[str, Any]) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n")


def generate_variant(variant: str) -> None:
    cfg = VARIANTS[variant]
    out_dir = OUTPUT_DIR / variant
    out_dir.mkdir(parents=True, exist_ok=True)

    _write_json(out_dir / "opencode.jsonc", _build_opencode_json(variant, cfg))
    _write_json(out_dir / "oh-my-opencode.json", _build_oh_my_opencode_json(variant))
    _write_json(out_dir / "antigravity.json", _build_antigravity_json())

def main() -> None:
    print(f"Generating configs into {OUTPUT_DIR}/")
    for variant in VARIANTS:
        generate_variant(variant)
        print(f"  \u2713 {variant}")
    print("Done.")


if __name__ == "__main__":
    main()
