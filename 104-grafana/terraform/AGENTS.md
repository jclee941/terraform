# AGENTS: 104-grafana/terraform

## OVERVIEW

Nested Grafana provider workspace. Manages folders, dashboards, contact points, notification policy, alert rule groups, and service-account tokens against the running Grafana instance.

## STRUCTURE

```text
104-grafana/terraform/
├── main.tf                 # Folder and dashboard resources
├── alerting_locals.tf      # Rule definitions and alert metadata
├── alerting_rules.tf       # Rule groups wired from locals
├── contact_points.tf       # Slack and fallback contact points
├── notification_policy.tf  # Default alert routing policy
├── service_accounts.tf     # Terraform and monitoring service accounts
├── onepassword.tf          # Provider auth via shared secret module
├── checks.tf               # Workspace-level validation checks
└── README.md               # terraform-docs output
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Dashboard resource loading | `main.tf` | Reads sibling `../dashboards/*.json`. |
| Alert definitions | `alerting_locals.tf` | Query, threshold, severity, annotations. |
| Alert rule groups | `alerting_rules.tf` | Homelab logs, infrastructure health, MCP alerts. |
| Contact points and policy | `contact_points.tf`, `notification_policy.tf` | Slack plus fallback routing. |
| Provider auth and secrets | `onepassword.tf` | Uses `modules/shared/onepassword-secrets`. |
| Validation tests | `tests/workspaces/grafana/grafana_test.tftest.hcl` | Mock-provider plan validation. |

## CONVENTIONS

- `../dashboards/*.json` remains the dashboard content source of truth; Terraform just loads and publishes it.
- Keep alert rules data-driven: definitions in locals, wiring in rule-group resources.
- Provider auth should stay 1Password-backed unless break-glass troubleshooting is explicitly required.
- Local apply is disabled; use `make plan SVC=grafana` for local review and CI for apply.

## ANTI-PATTERNS

- Do not make manual Grafana UI changes for Terraform-managed folders, dashboards, alerts, or service accounts.
- Do not introduce standalone alert YAML or duplicate query logic outside `alerting_locals.tf` and `alerting_rules.tf`.
- Do not hardcode tokens or change datasource names without updating dashboards, tests, and docs together.

## COMMANDS

```bash
make plan SVC=grafana
make validate SVC=grafana
cd tests/workspaces/grafana && terraform init -backend=false && terraform test
```
