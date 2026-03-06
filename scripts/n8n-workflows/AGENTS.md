# AGENTS: scripts/n8n-workflows — Workflow JSON Source of Truth

## OVERVIEW
Exported n8n workflow definitions used by infra automation. These JSON files are source-controlled artifacts that must match runtime workflows after UI import/publish.

## STRUCTURE
```text
scripts/n8n-workflows/
├── error-to-github-issue.json
├── glitchtip-sync.json
├── pr-notification.json
├── request-tracker.json
├── BUILD.bazel
├── OWNERS
└── AGENTS.md
```

## WHERE TO LOOK
| Task                      | Location                                                   | Notes                                     |
| ------------------------- | ---------------------------------------------------------- | ----------------------------------------- |
| Incident issue automation | `error-to-github-issue.json`                               | GlitchTip error to GitHub issue flow.     |
| Synchronization flows     | `glitchtip-sync.json`, `request-tracker.json`              | Webhook-triggered sync (POST `/webhook/glitchtip-sync`). |
| PR notifications          | `pr-notification.json`                                     | Pull request event notification pipeline. |
| Parent script policy      | `../AGENTS.md`                                             | Shared automation script conventions. |
| Alerting source context   | `../../104-grafana/AGENTS.md`                              | Upstream alert routing and contact-point behavior. |
| Runbook response context  | `../../docs/runbooks/AGENTS.md`                            | Incident procedures that consume workflow outputs. |

## CONVENTIONS
- Keep workflow IDs, node names, and credential references stable for deterministic diffs.
- Export from n8n UI after edits and commit the exact JSON output.
- Treat this directory as canonical workflow definition; runtime must mirror committed files.
- Keep `BUILD.bazel` and `OWNERS` intact for governance.

## ANTI-PATTERNS
- Do not edit runtime workflows in n8n without exporting and committing updated JSON.
- Do not commit secrets, tokens, webhook signing keys, or plaintext credentials in workflow JSON.
- Do not rename workflow files without updating references in runbooks/automation docs.
- Do not add one-off temporary workflows that are not linked to a tracked operational need.

## COMMANDS
```bash
git diff -- scripts/n8n-workflows/*.json
```
