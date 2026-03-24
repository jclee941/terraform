#!/usr/bin/env python3
"""Validate MCP server catalog consistency.

Reads the SSoT catalog (mcp_servers.json) and validates:
1. Schema correctness (required fields per location type)
2. Port uniqueness for hub servers
3. No duplicate server names
4. No secrets or tokens committed (env var placeholders only)
5. Env-var cross-validation against .env.tftpl template

Usage:
    python3 validate_mcps.py [--catalog PATH] [--env-template PATH]
"""

import json
import re
import sys
from pathlib import Path

CATALOG_DEFAULT = Path(__file__).parent / "mcp_servers.json"
ENV_TEMPLATE_DEFAULT = Path(__file__).parent / "templates" / ".env.tftpl"

VALID_LOCATIONS = {"hub", "local", "external"}
VALID_TRANSPORTS = {"stdio", "sse", "http", "streamable-http"}

# Patterns that indicate committed secrets
SECRET_PATTERNS = [
    re.compile(r"eyJ[A-Za-z0-9_-]{10,}"),  # JWT tokens
    re.compile(r"sk-[A-Za-z0-9]{20,}"),  # API keys
    re.compile(r"ghp_[A-Za-z0-9]{20,}"),  # GitHub PATs
    re.compile(r"xoxb-[A-Za-z0-9-]{20,}"),  # Slack bot tokens
    re.compile(r"xoxp-[A-Za-z0-9-]{20,}"),  # Slack user tokens
    re.compile(r"xoxe\.xoxp-[A-Za-z0-9-]{20,}"),  # Slack rotatable tokens
]


def validate_catalog(catalog_path: Path) -> list[str]:
    """Validate the MCP server catalog. Returns list of errors."""
    errors: list[str] = []

    if not catalog_path.exists():
        return [f"Catalog not found: {catalog_path}"]

    try:
        with open(catalog_path) as f:
            catalog = json.load(f)
    except json.JSONDecodeError as e:
        return [f"Invalid JSON: {e}"]

    # Top-level fields
    if "mcp_host" not in catalog:
        errors.append("Missing required field: mcp_host")
    if "servers" not in catalog:
        errors.append("Missing required field: servers")
        return errors

    servers = catalog["servers"]
    if not isinstance(servers, dict):
        errors.append("'servers' must be an object")
        return errors

    # Track ports for uniqueness
    ports: dict[int, str] = {}

    for name, server in servers.items():
        prefix = f"servers.{name}"

        # Location validation
        location = server.get("location")
        if location not in VALID_LOCATIONS:
            errors.append(
                f"{prefix}: invalid location '{location}' "
                f"(must be one of {VALID_LOCATIONS})"
            )
            continue

        # Transport validation for hub servers
        if location == "hub":
            transport = server.get("transport", "stdio")
            if transport not in VALID_TRANSPORTS:
                errors.append(
                    f"{prefix}: invalid transport '{transport}' "
                    f"(must be one of {VALID_TRANSPORTS})"
                )

            # Port required for hub servers (except http and url-based SSE)
            port = server.get("port")
            if port is None and transport != "http" and "url" not in server:
                errors.append(f"{prefix}: hub server missing 'port'")
            elif port is not None:
                if port in ports:
                    errors.append(
                        f"{prefix}: port {port} conflicts with '{ports[port]}'"
                    )
                else:
                    ports[port] = name

            # Stdio servers need command
            if transport == "stdio":
                if "command" not in server:
                    errors.append(f"{prefix}: stdio server missing 'command'")

            # SSE sidecar servers need docker_service
            if transport == "sse" and server.get("sidecar"):
                if "docker_service" not in server:
                    errors.append(f"{prefix}: sidecar server missing 'docker_service'")

            # HTTP servers need port and path
            if transport == "http":
                if "port" not in server:
                    errors.append(f"{prefix}: http server missing 'port'")

            # Streamable HTTP servers need url
            if transport == "streamable-http":
                if "url" not in server:
                    errors.append(f"{prefix}: streamable-http server missing 'url'")
        elif location == "local":
            if "command" not in server:
                errors.append(f"{prefix}: local server missing 'command'")

        elif location == "external":
            if "url" not in server:
                errors.append(f"{prefix}: external server missing 'url'")

        # Secret detection in all string values
        _check_secrets(server, prefix, errors)

    return errors


def _check_secrets(obj: object, prefix: str, errors: list[str]) -> None:
    """Recursively check for committed secrets."""
    if isinstance(obj, str):
        # Allow ${} placeholders
        if obj.startswith("${") and obj.endswith("}"):
            return
        for pattern in SECRET_PATTERNS:
            if pattern.search(obj):
                errors.append(
                    f"{prefix}: possible secret detected (matches {pattern.pattern})"
                )
                break
    elif isinstance(obj, dict):
        for k, v in obj.items():
            _check_secrets(v, f"{prefix}.{k}", errors)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            _check_secrets(v, f"{prefix}[{i}]", errors)


def _parse_env_template(template_path: Path) -> set[str]:
    """Extract env var names (LHS of '=') from a .env.tftpl file."""
    names: set[str] = set()
    if not template_path.exists():
        return names
    for line in template_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            names.add(line.split("=", 1)[0])
    return names


def _check_env_vars(
    catalog_path: Path,
    env_template_path: Path,
) -> list[str]:
    """Check that every ${VAR} in catalog env blocks exists in .env.tftpl."""
    errors: list[str] = []
    if not env_template_path.exists():
        return errors

    template_vars = _parse_env_template(env_template_path)

    with open(catalog_path) as f:
        catalog = json.load(f)

    placeholder_re = re.compile(r"\$\{([^}]+)\}")

    for name, server in catalog.get("servers", {}).items():
        env = server.get("env", {})
        for key, val in env.items():
            match = placeholder_re.fullmatch(val)
            if match:
                ref = match.group(1)
                if ref not in template_vars:
                    errors.append(
                        f"servers.{name}.env.{key}: placeholder "
                        f"${{{ref}}} not found in {env_template_path.name}"
                    )
    return errors


def main() -> int:
    catalog_path = CATALOG_DEFAULT
    env_template_path = ENV_TEMPLATE_DEFAULT

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--catalog" and i + 1 < len(args):
            catalog_path = Path(args[i + 1])
            i += 2
        elif args[i] == "--env-template" and i + 1 < len(args):
            env_template_path = Path(args[i + 1])
            i += 2
        else:
            i += 1

    errors = validate_catalog(catalog_path)
    env_errors = _check_env_vars(catalog_path, env_template_path)
    errors.extend(env_errors)

    if errors:
        print(f"❌ Catalog validation FAILED ({len(errors)} errors):")
        for err in errors:
            print(f"  • {err}")
        return 1

    with open(catalog_path) as f:
        catalog = json.load(f)

    servers = catalog["servers"]
    hub = sum(1 for s in servers.values() if s["location"] == "hub")
    local = sum(1 for s in servers.values() if s["location"] == "local")
    external = sum(1 for s in servers.values() if s["location"] == "external")

    transports: dict[str, int] = {}
    for s in servers.values():
        t = s.get("transport", "stdio")
        transports[t] = transports.get(t, 0) + 1
    transport_summary = ", ".join(f"{t}={c}" for t, c in sorted(transports.items()))

    env_var_count = sum(len(s.get("env", {})) for s in servers.values())
    template_var_count = len(_parse_env_template(env_template_path))

    print(
        f"✅ Catalog valid: {len(servers)} servers "
        f"(hub={hub}, local={local}, external={external})"
    )
    print(f"   Transports: {transport_summary}")
    print(f"   Env refs: {env_var_count} catalog → {template_var_count} template vars")
    return 0


if __name__ == "__main__":
    sys.exit(main())
