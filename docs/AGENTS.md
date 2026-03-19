# AGENTS: docs

## OVERVIEW

Project documentation, runbooks, architecture decisions, and operational guides.

## STRUCTURE

```
docs/
├── adr/                          # Architecture Decision Records
├── runbooks/                     # Operational procedures (incident response)
├── cloudflare-token-rotation.md  # Security rotation procedures
├── backup-strategy.md            # Restic/Borg backup policies
├── secret-management.md          # Secret management strategy and patterns
├── workspace-ordering.md         # Service directory numbering conventions
└── ALERTING-REFERENCE.md         # Explanations of Grafana alert rules
```

## WHERE TO LOOK

| Topic                      | File                           | Notes                                                    |
| -------------------------- | ------------------------------ | -------------------------------------------------------- |
| **Architecture Decisions** | `adr/`                         | Immutable decision records with context and consequences |
| **System Architecture**    | `../ARCHITECTURE.md`           | High-level system topology and service relationships     |
| **Incident Response**      | `runbooks/`                    | Step-by-step recovery guides                             |
| **Token Rotation**         | `cloudflare-token-rotation.md` | Quarterly rotation steps                                 |
| **Backups**                | `backup-strategy.md`           | 3-2-1 strategy details                                   |
| **Secrets**                | `secret-management.md`         | 1Password integration and secret lifecycle                   |
| **Service Numbering**      | `workspace-ordering.md`        | VMID/directory numbering rationale                       |
| **Alerts**                 | `ALERTING-REFERENCE.md`        | Rule definitions, thresholds, n8n bridge routing         |

## CONVENTIONS

- **Runbooks**: Must be actionable, not theoretical. "Do X, then Y".
- **Token Rotation**: strict adherence to `cloudflare-token-rotation.md` prevents outage.
- **ADRs**: Append-only. Supersede with new ADR, never modify existing ones.

## ANTI-PATTERNS

- **NO stale docs**: Update runbooks immediately after incident resolution.
- **NO secrets**: Never document actual keys/tokens, only IDs or locations.
