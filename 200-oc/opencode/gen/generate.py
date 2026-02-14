"""Generate opencode config files for all variants.

Reads agent/category definitions from config.py, resolves model IDs via
model_id.py, and writes JSON configs + rendered Jinja2 templates to
``generated/{variant}/``.

Usage::

    python3 gen/generate.py            # Generate all variants
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent))

from config import (
    AGENTS,
    ANTIGRAVITY,
    CATEGORIES,
    DCP,
    FORMATTER,
    GITHUB_COPILOT_MODELS,
    GOOGLE_MODELS,
    LOCAL_MCP_ENV_OVERRIDES,
    LOCAL_MCPS,
    MCPHUB_URL,
    MCP_TIMEOUT,
    OC_PATHS,
    OPENCODE_BASE,
    PLUGINS,
    VARIANTS,
)
from model_id import resolve_agents, resolve_categories

try:
    from jinja2 import Environment, FileSystemLoader
except ImportError:
    print("ERROR: jinja2 not installed. Run: pip3 install jinja2", file=sys.stderr)
    sys.exit(1)


ROOT = Path(__file__).resolve().parent.parent
TEMPLATE_DIR = ROOT / "templates"
OUTPUT_DIR = ROOT / "generated"


def _expand_tilde(s: str) -> str:
    return s.replace("~", OC_PATHS["home"])


# -- JSON builders -----------------------------------------------------------


def _build_opencode_json(variant: str, cfg: dict) -> dict:
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


def _build_oh_my_opencode_json(variant: str) -> dict:
    """Build oh-my-opencode.json for a variant using resolved model IDs."""
    agents = resolve_agents(variant, AGENTS)
    categories = resolve_categories(variant, CATEGORIES)
    return {
        "$schema": "oh-my-opencode.schema.json",
        "google_auth": False,
        "agents": agents,
        "categories": categories,
    }


def _build_antigravity_json() -> dict:
    return {"$schema": "antigravity.schema.json", **ANTIGRAVITY}


def _build_dcp_jsonc() -> dict:
    return {
        "$schema": "https://raw.githubusercontent.com/Opencode-DCP/opencode-dynamic-context-pruning/master/dcp.schema.json",
        **DCP,
    }


# -- Generator ----------------------------------------------------------------


def _write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n")


def generate_variant(variant: str, jinja_env: Environment) -> None:
    cfg = VARIANTS[variant]
    port = cfg["port"]
    out_dir = OUTPUT_DIR / variant
    out_dir.mkdir(parents=True, exist_ok=True)

    _write_json(out_dir / "opencode.jsonc", _build_opencode_json(variant, cfg))
    _write_json(out_dir / "oh-my-opencode.json", _build_oh_my_opencode_json(variant))
    _write_json(out_dir / "antigravity.json", _build_antigravity_json())
    _write_json(out_dir / "dcp.jsonc", _build_dcp_jsonc())

    xdg_config_home = f"{OC_PATHS['home']}/.config/opencode-wt-{variant}"
    service = jinja_env.get_template("opencode.service.j2").render(
        variant=variant,
        xdg_config_home=xdg_config_home,
        nvm_path=_expand_tilde(OC_PATHS["nvm_bin"]),
        opencode_bin=_expand_tilde(OC_PATHS["opencode_bin"]),
        port=port,
    )
    (out_dir / f"opencode-{variant}.service").write_text(service)

    wrapper = jinja_env.get_template("opencode-wrapper.sh.j2").render(
        variant=variant,
        port=port,
    )
    wrapper_path = out_dir / f"opencode-{variant}"
    wrapper_path.write_text(wrapper)
    wrapper_path.chmod(0o755)


def main() -> None:
    jinja_env = Environment(
        loader=FileSystemLoader(str(TEMPLATE_DIR)),
        keep_trailing_newline=True,
        trim_blocks=True,
        lstrip_blocks=True,
    )

    print(f"Generating configs into {OUTPUT_DIR}/")
    for variant in VARIANTS:
        generate_variant(variant, jinja_env)
        print(f"  \u2713 {variant}")
    print("Done.")


if __name__ == "__main__":
    main()
