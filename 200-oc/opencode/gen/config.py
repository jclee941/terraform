"""Configuration data for opencode variant generation.

Single source of truth for all agents, categories, MCPs, plugins, and variant
definitions. Replaces the Terraform variables.tf data.
"""

from __future__ import annotations

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
MCP_HOST = "192.168.50.112"

# ---------------------------------------------------------------------------
# Remote MCP Servers (running on MCP_HOST)
# ---------------------------------------------------------------------------
REMOTE_MCPS: dict[str, dict] = {
    "sqlite": {"port": 8054},
    "proxmox": {"port": 8055},
    "playwright": {"port": 8056},
    "sequential-thinking": {"port": 8057},

    "elk": {"port": 8065},
    "websearch": {"port": 8067},
    "context7": {"port": 8068},
    "grafana": {"port": 8069},
    "terraform": {"port": 8071},
    "splunk": {"port": 8074},
}

# ---------------------------------------------------------------------------
# Local MCP Servers (run on the VM itself)
# ---------------------------------------------------------------------------
LOCAL_MCPS: dict[str, dict] = {
    "in-memoria": {
        "command": ["npx", "-y", "in-memoria", "server"],
        "environment": {
            "IN_MEMORIA_BATCH_SIZE": "25",
            "IN_MEMORIA_MAX_CONCURRENT": "5",
            "IN_MEMORIA_LOG_LEVEL": "warn",
        },
    },
    "bazel": {
        "command": ["npx", "-y", "github:nacgarg/bazel-mcp-server"],
    },
    "git": {
        "command": ["npx", "-y", "@cyanheads/git-mcp-server@latest"],
    },
    "kratos": {
        "command": ["npx", "-y", "kratos-mcp"],
    },
    "cf-docs": {
        "command": ["npx", "-y", "mcp-remote", "https://docs.mcp.cloudflare.com/sse"],
    },
    "github": {
        "command": ["npx", "-y", "@modelcontextprotocol/server-github"],
        "environment": {
            "GITHUB_PERSONAL_ACCESS_TOKEN": "",
        },
    },
}

# ---------------------------------------------------------------------------
# N8N
# ---------------------------------------------------------------------------
N8N_MCP_URL = "http://192.168.50.112:5678/mcp-server/http"
N8N_JWT = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJzdWIiOiIwMjhlMzcyZi02YTg4LTRlZTctYTY1Ny0xMTljN2MyOWM1ZWQiLCJpc3MiOiJu"
    "OG4iLCJhdWQiOiJtY3Atc2VydmVyLWFwaSIsImp0aSI6IjZmOGM0MGMwLWVmYzAtNDQ5OC05"
    "MzZmLWY1MGU1MjNhNzY0ZCIsImlhdCI6MTc3MDQ1NzkwN30."
    "k0oFPJ8feVCoG28mjU5EkdUYr6hKMdXDWu2HgrLr5Jc"
)
MCP_TIMEOUT = 60000

# ---------------------------------------------------------------------------
# Plugins
# ---------------------------------------------------------------------------
PLUGINS: list[str] = [
    "opencode-antigravity-auth@beta",
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
        "name": "Claude Sonnet 4.6 (Antigravity)",
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
        "limit": {"context": 200000, "output": 8192},
        "modalities": {
            "input": ["text"],
            "output": ["text"],
        },
    },
    "claude-sonnet-4.5": {
        "name": "Claude Sonnet 4.5 (GitHub Copilot)",
        "limit": {"context": 200000, "output": 8192},
        "modalities": {
            "input": ["text"],
            "output": ["text"],
        },
    },
    "claude-opus-4.6": {
        "name": "Claude Opus 4.6 (GitHub Copilot)",
        "limit": {"context": 200000, "output": 8192},
        "modalities": {
            "input": ["text"],
            "output": ["text"],
        },
    },
}
