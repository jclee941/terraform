# docs/ Documentation

## OVERVIEW
Project documentation, runbooks, and operational guides.

## STRUCTURE
```
docs/
├── runbooks/                     # Operational procedures (incident response)
├── cloudflare-token-rotation.md  # Security rotation procedures
├── backup-strategy.md            # Restic/Borg backup policies
└── ALERTING-REFERENCE.md         # Explanations of Grafana alert rules
```

## WHERE TO LOOK
| Topic | File | Notes |
|-------|------|-------|
| **Incident Response** | `runbooks/` | Step-by-step recovery guides |
| **Token Rotation** | `cloudflare-token-rotation.md` | Quarterly rotation steps |
| **Backups** | `backup-strategy.md` | 3-2-1 strategy details |
| **Alerts** | `ALERTING-REFERENCE.md` | Rule definitions & thresholds |

## CONVENTIONS
- **Runbooks**: Must be actionable, not theoretical. "Do X, then Y".
- **Token Rotation**: strict adherence to `cloudflare-token-rotation.md` prevents outage.

## ANTI-PATTERNS
- **NO stale docs**: Update runbooks immediately after incident resolution.
- **NO secrets**: Never document actual keys/tokens, only IDs or locations.
