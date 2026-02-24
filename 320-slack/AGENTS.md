# 320-slack — Slack Workspace Management

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
├── versions.tf      # Provider requirements + backend
├── variables.tf     # Slack auth variables
└── onepassword.tf   # 1Password secret lookup
```

## WHERE TO LOOK

| Task               | Location         | Notes                          |
| ------------------ | ---------------- | ------------------------------ |
| Provider config    | `main.tf`        | Slack bot token auth           |
| Channel management | `main.tf`        | `slack_conversation` resources |
| Secret lookup      | `onepassword.tf` | Bot token from 1Password       |
| Auth variables     | `variables.tf`   | Token override support         |

## CONVENTIONS

- Auth: Bot token via 1Password, with variable fallback.
- Channel naming: kebab-case, prefixed by purpose (e.g. `ops-`, `dev-`, `alert-`).
- Existing channels: use `adopt_existing_channel = true` for import.

## ANTI-PATTERNS

- Never hardcode Slack tokens in TF files.
- Never manage DMs or private messages via Terraform.

## COMMANDS

```bash
# From repo root
cd 320-slack && terraform init
terraform plan
terraform apply
```
