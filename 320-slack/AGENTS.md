# AGENTS: 320-slack

## OVERVIEW

Terraform-managed Slack workspace: channel lifecycle, usergroups, and membership via the `pablovarela/slack` provider.

## STRUCTURE

```text
320-slack/
├── AGENTS.md
├── BUILD.bazel
├── OWNERS
├── README.md
├── main.tf          # Provider config + channel resources
├── channels.tf      # Channel definitions (slack_conversation)
├── versions.tf      # Provider requirements + backend
├── variables.tf     # Slack auth variables (with validation)
└── onepassword.tf   # 1Password secret lookup
```

## WHERE TO LOOK

| Task               | Location         | Notes                          |
| ------------------ | ---------------- | ------------------------------ |
| Provider config    | `main.tf`        | Slack bot token auth           |
| Channel management | `channels.tf`    | `slack_conversation` resources |
| Secret lookup      | `onepassword.tf` | Bot token from 1Password       |
| Auth variables     | `variables.tf`   | Token override + validation    |
| CI plan/apply      | `.github/workflows/slack-{plan,apply}.yml` | Reusable `_terraform-*` wrappers |

## CONVENTIONS

- Auth: Bot token via 1Password, with variable fallback.
- Channel management is conditional: `local._slack_enabled` gates all `slack_conversation` resources. When bot token is unavailable, channels are skipped gracefully.
- Channel naming: kebab-case, prefixed by purpose (e.g. `ops-`, `dev-`, `alert-`).
- Existing channels: use `adopt_existing_channel = true` for import.

## ANTI-PATTERNS

- Never hardcode Slack tokens in TF files.
- Never manage DMs or private messages via Terraform.

## COMMANDS

```bash
make plan SVC=slack
# make apply is DISABLED locally — applies go through CI/CD
```
