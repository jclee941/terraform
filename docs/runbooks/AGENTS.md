# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-22 22:31:51 Asia/Seoul
**Commit:** b6e4683
**Branch:** master

## OVERVIEW

Runbooks in this directory are executable incident and operations procedures for homelab Terraform services.

## STRUCTURE

```text
docs/runbooks/
├── *.md          # Incident/operation runbooks
└── (no generated outputs in this scope)
```

## WHERE TO LOOK

| Task                       | Location                                    | Notes                                     |
| -------------------------- | ------------------------------------------- | ----------------------------------------- |
| Service outage response    | `docs/runbooks/*incident*.md`               | Follow ordered triage and recovery steps. |
| Deployment/maintenance ops | `docs/runbooks/*maintenance*.md`            | Use rollback-ready command sequences.     |
| Cross-service references   | `docs/architecture.md`, service `AGENTS.md` | Confirm system boundaries before action.  |
| ELK index migration        | `docs/runbooks/elk-index-migration.md`      | Logstash index pattern fix + stale cleanup. |
| MCP health triage          | `docs/runbooks/mcp-health-check.md`         | Fix procedures for 1P, Supabase, GlitchTip. |
| Policy baseline            | `docs/AGENTS.md`                            | Parent docs conventions and constraints.  |

## CONVENTIONS

- Keep runbooks command-first and copy/paste safe.
- Include rollback path for any state-changing procedure.
- Use concrete host/service identifiers matching Terraform inventory naming.
- Update runbook steps after real incidents when drift is discovered.

## ANTI-PATTERNS (THIS DIRECTORY)

- NEVER store secrets, tokens, or private keys in runbook text.
- NEVER leave ambiguous instructions like "check logs" without command/path.
- NEVER document manual config mutations that bypass IaC unless explicitly marked as emergency-only.
- NEVER omit verification checkpoints after remediation steps.

## NOTES

- Align terminology with workspace/service directories (`100-pve`, `105-elk`, `112-mcphub`, etc.).
- Keep procedures short, ordered, and deterministic to reduce incident latency.
