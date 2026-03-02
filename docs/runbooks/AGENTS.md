# AGENTS: docs/runbooks

## OVERVIEW
Runbooks in this directory are executable incident and operations procedures for homelab Terraform services.

## STRUCTURE
```text
docs/runbooks/
├── service-down.md
├── service-deployment.md
├── mcp-health-check.md
├── elk-index-migration.md
├── disaster-recovery.md
├── ...                     # Additional incident/ops runbooks
├── BUILD.bazel
├── OWNERS
└── AGENTS.md
```

## WHERE TO LOOK
| Task                       | Location                                    | Notes                                       |
| -------------------------- | ------------------------------------------- | ------------------------------------------- |
| Service outage response    | `docs/runbooks/service-down.md`, `docs/runbooks/troubleshooting.md` | Ordered triage and recovery flow. |
| Deployment/maintenance ops | `docs/runbooks/service-deployment.md`, `docs/runbooks/state-locking.md` | Deployment failure and lock recovery steps. |
| ELK index migration        | `docs/runbooks/elk-index-migration.md`      | Logstash index pattern fix + stale cleanup. |
| MCP health triage          | `docs/runbooks/mcp-health-check.md`         | Fix procedures for 1P, Supabase, GlitchTip. |
| Service recovery baseline  | `docs/runbooks/service-down.md`             | Generic service triage/escalation flow. |
| Deploy troubleshooting     | `docs/runbooks/service-deployment.md`       | Deployment failure checks and rollback checkpoints. |
| Data/backup recovery       | `docs/runbooks/backup-restore.md`, `docs/runbooks/disaster-recovery.md` | Restore sequence and DR escalation path. |
| Policy baseline            | `docs/AGENTS.md`                            | Parent docs conventions and constraints.    |
| Infra context references   | `../../100-pve/AGENTS.md`, `../../104-grafana/AGENTS.md`, `../../105-elk/AGENTS.md` | Use service-specific procedures with matching workspace rules. |

## CONVENTIONS
- Keep runbooks command-first and copy/paste safe.
- Include rollback path for any state-changing procedure.
- Use concrete host/service identifiers matching Terraform inventory naming.
- Update runbook steps after real incidents when drift is discovered.

## ANTI-PATTERNS
- NEVER store secrets, tokens, or private keys in runbook text.
- NEVER leave ambiguous instructions like "check logs" without command/path.
- NEVER document manual config mutations that bypass IaC unless explicitly marked as emergency-only.
- NEVER omit verification checkpoints after remediation steps.

## NOTES
- Align terminology with workspace/service directories (`100-pve`, `105-elk`, `112-mcphub`, etc.).
- Keep procedures short, ordered, and deterministic to reduce incident latency.
