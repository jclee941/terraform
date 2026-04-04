# AGENTS: 108-archon/scripts — Archon Operational Scripts

## OVERVIEW
Go scripts for Archon server management and agent orchestration.

## STRUCTURE
```
scripts/
└── *.go                   # Operational tooling
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Server ops | `*.go` | Start, stop, status, logs |
| Agent management | `*.go` | Work order submission, monitoring |

## CONVENTIONS
- Use stdlib-only Go scripts
- Interact with Archon API at localhost:8181
- Use `os/exec` for Docker Compose commands

## ANTI-PATTERNS
- NEVER use shell scripts — Go only per monorepo standards
- NEVER hardcode credentials — use 1Password
