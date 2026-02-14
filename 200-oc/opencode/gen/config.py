"""Configuration data for opencode variant generation.

Single source of truth for all agents, categories, MCPs, plugins, and variant
definitions. Replaces the Terraform variables.tf data.
"""

from __future__ import annotations

import json
from pathlib import Path

from model_id import AgentSpec

# ---------------------------------------------------------------------------
# Agents
# ---------------------------------------------------------------------------
AGENTS: dict[str, AgentSpec] = {
    "sisyphus": AgentSpec("claude-opus-4-6-thinking", "anthropic", thinking_budget="max"),
    "prometheus": AgentSpec("claude-opus-4-6-thinking", "anthropic", thinking_budget="max"),
    "metis": AgentSpec("claude-opus-4-6-thinking", "anthropic", thinking_budget="max"),
    "momus": AgentSpec("gpt-5.2", "openai", thinking_budget="medium"),
    "atlas": AgentSpec("claude-sonnet-4-5", "anthropic"),
    "oracle": AgentSpec("gpt-5.2", "openai", thinking_budget="high"),
    "librarian": AgentSpec("claude-sonnet-4-5", "anthropic"),
    "explore": AgentSpec("claude-haiku-4-5", "anthropic"),
    "multimodal-looker": AgentSpec("gemini-3-flash", "google"),
}

# ---------------------------------------------------------------------------
# Categories
# ---------------------------------------------------------------------------
CATEGORIES: dict[str, AgentSpec] = {
    "visual-engineering": AgentSpec("gemini-3-pro", "google"),
    "ultrabrain": AgentSpec("gpt-5.3-codex", "openai", thinking_budget="xhigh"),
    "deep": AgentSpec("gpt-5.3-codex", "openai", thinking_budget="medium"),
    "artistry": AgentSpec("gemini-3-pro", "google", thinking_budget="high"),
    "quick": AgentSpec("claude-haiku-4-5", "anthropic"),
    "unspecified-low": AgentSpec("claude-sonnet-4-5", "anthropic"),
    "unspecified-high": AgentSpec("claude-opus-4-6-thinking", "anthropic", thinking_budget="max"),
    "writing": AgentSpec("gemini-3-flash", "google"),
}

# ---------------------------------------------------------------------------
# Variants
# ---------------------------------------------------------------------------
VARIANTS: dict[str, dict] = {
    "anti": {"port": 3001},
    "claude": {"port": 3002},
    "copilot": {"port": 3003},
}

# ---------------------------------------------------------------------------
# MCP Host
# ---------------------------------------------------------------------------
CATALOG_PATH = Path(__file__).resolve().parents[3] / "112-mcphub" / "mcp_servers.json"


def _load_catalog() -> dict:
    with open(CATALOG_PATH, encoding="utf-8") as f:
        return json.load(f)


_catalog = _load_catalog()
MCP_HOST = _catalog["mcp_host"]
MCP_TIMEOUT = _catalog.get("mcp_timeout", 60000)

# MCPHub gateway URL — single aggregated endpoint for all hub-hosted servers.
MCPHUB_URL = f"http://{MCP_HOST}:3000/mcp"

# ---------------------------------------------------------------------------
LOCAL_MCPS: dict[str, dict] = {
    name: server
    for name, server in _catalog["servers"].items()
    if server["location"] == "local"
}

# OC VM-specific overrides for local MCPs (not in catalog SSoT).
LOCAL_MCP_ENV_OVERRIDES: dict[str, dict[str, str]] = {
    "in-memoria": {
        "IN_MEMORIA_DB_FILENAME": "data/in-memoria.db",
        "IN_MEMORIA_VECTOR_DB_PATH": "data/in-memoria-vectors.db",
    },
}

# ---------------------------------------------------------------------------
# Plugins
# ---------------------------------------------------------------------------
PLUGINS: list[str] = [
    "opencode-antigravity-auth@latest",
    "@franlol/opencode-md-table-formatter",
    "open-trees",
    "@tarquinen/opencode-dcp@latest",
    "opencode-pty@0.1.4",
    "opencode-supermemory@0.1.6",
    "oh-my-opencode",
    "opencode-agent-skills",
]

# ---------------------------------------------------------------------------
# Opencode Base Config
# ---------------------------------------------------------------------------
OPENCODE_BASE = {
    "$schema": "https://opencode.ai/config.json",
    "theme": "tron",
    "default_agent": "Sisyphus",
    "username": "jclee",
    "small_model": "google/antigravity-gemini-3-flash",
    "instructions": ["/home/jclee/.config/opencode/rules/session-init.md"],
    "permission": {"*": "allow"},
    "experimental": {
        "continue_loop_on_deny": True,
        "batch_tool": True,
    },
    "keybinds": {
        "leader": "ctrl+x",
        "tool_details": "<leader>d",
        "session_fork": "<leader>f",
    },
    "compaction": {
        "auto": True,
        "prune": True,
    },
}

# ---------------------------------------------------------------------------
# Formatter (per-extension commands, no $FILE placeholder)
# ---------------------------------------------------------------------------
FORMATTER: dict[str, dict] = {
    ".ts": {"command": ["prettier", "--write"]},
    ".tsx": {"command": ["prettier", "--write"]},
    ".js": {"command": ["prettier", "--write"]},
    ".jsx": {"command": ["prettier", "--write"]},
    ".py": {"command": ["ruff", "format"]},
    ".go": {"command": ["gofmt", "-w"]},
    ".json": {"command": ["prettier", "--write"]},
    ".yaml": {"command": ["prettier", "--write"]},
    ".yml": {"command": ["prettier", "--write"]},
    ".md": {"command": ["prettier", "--write"]},
}

# ---------------------------------------------------------------------------
# Antigravity Config
# ---------------------------------------------------------------------------
ANTIGRAVITY = {
    "debug": False,
    "log_level": "info",
    "keep_thinking": False,
    "max_rate_limit_wait_seconds": 120,
    "switch_on_first_rate_limit": True,
    "quota_fallback": True,
    "proactive_token_refresh": True,
    "pid_offset_enabled": False,
    "account_selection_strategy": "round-robin",
    "empty_response_max": 3,
    "empty_response_delay": 2000,
    "session_recovery": True,
    "tool_id_recovery": True,
    "claude_tool_hardening": True,
    "web_search": {"default_mode": "auto"},
}

# ---------------------------------------------------------------------------
# DCP (Dynamic Context Pruning) Config
# ---------------------------------------------------------------------------
DCP: dict = {
    "enabled": True,
    "debug": False,
    "pruneNotification": "detailed",
    "pruneNotificationType": "chat",
    "commands": {"enabled": True, "protectedTools": []},
    "turnProtection": {"enabled": False, "turns": 4},
    "protectedFilePatterns": [],
    "tools": {
        "settings": {
            "nudgeEnabled": True,
            "nudgeFrequency": 10,
            "protectedTools": [],
            "contextLimit": "80%",
        },
        "distill": {"permission": "allow", "showDistillation": False},
        "compress": {"permission": "allow", "showCompression": False},
        "prune": {"permission": "allow"},
    },
    "strategies": {
        "deduplication": {"enabled": True, "protectedTools": []},
        "supersedeWrites": {"enabled": False},
        "purgeErrors": {"enabled": True, "turns": 4, "protectedTools": []},
    },
}

# ---------------------------------------------------------------------------
# Paths on the target VM (200-oc)
# ---------------------------------------------------------------------------
OC_PATHS = {
    "home": "/home/jclee",
    "opencode_bin": "~/.opencode/bin/opencode",
    "nvm_bin": "~/.nvm/versions/node/v22.22.0/bin",
}

# ---------------------------------------------------------------------------
# Antigravity Google Models (defined in provider.google.models)
# ---------------------------------------------------------------------------
GOOGLE_MODELS: dict[str, dict] = {
    "antigravity-gemini-3-pro": {
        "name": "Gemini 3 Pro (Antigravity)",
        "limit": {"context": 1048576, "output": 65535},
        "modalities": {
            "input": ["text", "image", "pdf"],
            "output": ["text"],
        },
        "variants": {
            "low": {"thinkingLevel": "low"},
            "high": {"thinkingLevel": "high"},
        },
    },
    "antigravity-gemini-3-flash": {
        "name": "Gemini 3 Flash (Antigravity)",
        "limit": {"context": 1048576, "output": 65536},
        "modalities": {
            "input": ["text", "image", "pdf"],
            "output": ["text"],
        },
        "variants": {
            "minimal": {"thinkingLevel": "minimal"},
            "low": {"thinkingLevel": "low"},
            "medium": {"thinkingLevel": "medium"},
            "high": {"thinkingLevel": "high"},
        },
    },
    "antigravity-claude-sonnet-4-5": {
        "name": "Claude Sonnet 4.5 (Antigravity)",
        "limit": {"context": 200000, "output": 64000},
        "modalities": {
            "input": ["text", "image", "pdf"],
            "output": ["text"],
        },
    },
    "antigravity-claude-sonnet-4-5-thinking": {
        "name": "Claude Sonnet 4.5 Thinking (Antigravity)",
        "limit": {"context": 200000, "output": 64000},
        "modalities": {
            "input": ["text", "image", "pdf"],
            "output": ["text"],
        },
        "variants": {
            "low": {"thinkingConfig": {"thinkingBudget": 8192}},
            "max": {"thinkingConfig": {"thinkingBudget": 32768}},
        },
    },
    "antigravity-claude-opus-4-6-thinking": {
        "name": "Claude Opus 4.6 Thinking (Antigravity)",
        "limit": {"context": 200000, "output": 64000},
        "modalities": {
            "input": ["text", "image", "pdf"],
            "output": ["text"],
        },
        "variants": {
            "low": {"thinkingConfig": {"thinkingBudget": 8192}},
            "max": {"thinkingConfig": {"thinkingBudget": 32768}},
        },
    },
}

# ---------------------------------------------------------------------------
# GitHub Copilot Models (defined in provider.github-copilot.models)
# ---------------------------------------------------------------------------
GITHUB_COPILOT_MODELS: dict[str, dict] = {
    "claude-haiku-4.5": {
        "name": "Claude Haiku 4.5 (GitHub Copilot)",
        "limit": {"context": 200000, "output": 64000},
        "modalities": {
            "input": ["text", "image", "pdf"],
            "output": ["text"],
        },
    },
    "claude-sonnet-4.5": {
        "name": "Claude Sonnet 4.5 (GitHub Copilot)",
        "limit": {"context": 200000, "output": 64000},
        "modalities": {
            "input": ["text", "image", "pdf"],
            "output": ["text"],
        },
        "variants": {
            "low": {"thinkingConfig": {"thinkingBudget": 8192}},
            "max": {"thinkingConfig": {"thinkingBudget": 32768}},
        },
    },
    "claude-opus-4.6": {
        "name": "Claude Opus 4.6 (GitHub Copilot)",
        "limit": {"context": 200000, "output": 64000},
        "modalities": {
            "input": ["text", "image", "pdf"],
            "output": ["text"],
        },
        "variants": {
            "low": {"thinkingConfig": {"thinkingBudget": 8192}},
            "max": {"thinkingConfig": {"thinkingBudget": 32768}},
        },
    },
}
