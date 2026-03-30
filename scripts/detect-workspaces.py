#!/usr/bin/env python3
"""
Workspace Detection Script for GitLab CI

Detects which Terraform workspaces are affected by changed files.
Outputs JSON list of affected workspaces for downstream pipeline jobs.
"""

import json
import sys
from pathlib import Path
from typing import List, Set

# Workspace to directory mapping
WORKSPACE_MAP = {
    "100-pve": ["100-pve/", "modules/"],
    "102-traefik": ["102-traefik/"],
    "104-grafana": ["104-grafana/"],
    "105-elk": ["105-elk/"],
    "108-archon": ["108-archon/"],
    "215-synology": ["215-synology/"],
    "300-cloudflare": ["300-cloudflare/"],
    "310-safetywallet": ["310-safetywallet/"],
    "320-slack": ["320-slack/"],
    "400-gcp": ["400-gcp/"],
}

# Template-only workspaces (no Terraform, but configs rendered)
TEMPLATE_WORKSPACES = [
    "101-runner",
    "103-coredns",
    "107-supabase",
    "109-gitops",
    "110-n8n",
    "112-mcphub",
    "200-oc",
    "220-youtube",
]


def detect_workspaces(changed_files: List[str]) -> List[str]:
    """Detect affected workspaces from changed files."""
    affected = set()

    for file in changed_files:
        file = file.strip()
        if not file:
            continue

        # Check each workspace mapping
        for workspace, prefixes in WORKSPACE_MAP.items():
            for prefix in prefixes:
                if file.startswith(prefix):
                    affected.add(workspace)
                    break

        # Special case: service templates affect 100-pve
        if any(file.startswith(f"{ws}/templates/") for ws in TEMPLATE_WORKSPACES):
            affected.add("100-pve")

    return sorted(list(affected))


def main():
    if len(sys.argv) < 2:
        # Read from stdin
        changed_files = sys.stdin.read().strip().split("\n")
    else:
        # Read from file
        with open(sys.argv[1], "r") as f:
            changed_files = f.read().strip().split("\n")

    workspaces = detect_workspaces(changed_files)

    # Output JSON for GitLab CI
    output = {
        "workspaces": workspaces,
        "count": len(workspaces),
        "changed_files": [f for f in changed_files if f.strip()],
    }

    print(json.dumps(output, indent=2))

    # Also output for dotenv
    print(f"export AFFECTED_WORKSPACES='{json.dumps(workspaces)}'")


if __name__ == "__main__":
    main()
