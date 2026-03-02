# AGENTS: 104-grafana/dashboards

## OVERVIEW

Dashboard JSON files in this directory are the source of truth for Grafana dashboard content deployed through Terraform.

## STRUCTURE

```text
104-grafana/dashboards/
├── archon-service.json
├── infra-overview.json
├── log-collection-health.json
├── logstash-metrics.json
├── ...                    # Remaining dashboard JSON definitions
├── README.md              # Inventory and usage notes
├── BUILD.bazel
└── OWNERS
```

## WHERE TO LOOK

| Task                            | Location                           | Notes                                       |
| ------------------------------- | ---------------------------------- | ------------------------------------------- |
| Dashboard source edits          | `104-grafana/dashboards/*.json`    | Edit panel/query/layout JSON directly.      |
| Dashboard catalog and ownership | `104-grafana/dashboards/README.md` | Keep list and usage guidance aligned.       |
| Terraform dashboard resources   | `../terraform/main.tf`             | `grafana_dashboard` resources load JSON files. |
| Alert and contact point linkage | `../terraform/contact_points.tf`   | Dashboard alerts route to n8n/GlitchTip pipeline. |
| Rendered output counterpart     | `../tf-configs/*.json`             | Terraform-rendered/interpolated dashboard outputs (read-only). |
| Service-level constraints       | `../AGENTS.md`                     | Parent scope for stack-wide rules. |
| Incident procedure linkage      | `../../docs/runbooks/AGENTS.md`    | Runbooks that depend on dashboard/alert semantics. |

## CONVENTIONS

- Keep dashboard `uid` stable once published.
- Keep dashboard titles deterministic; avoid cosmetic renames without reason.
- Preserve datasource/query compatibility with ELK-backed observability.

## ANTI-PATTERNS

- NEVER delete/recreate dashboards just to change panel layout when a targeted JSON edit works.
- NEVER introduce temporary test dashboards in committed JSON.
- NEVER hand-edit generated `tf-configs/` outputs instead of editing source JSON.

## NOTES

- Validate JSON structure before commit to avoid failed Terraform apply.
- Prefer small, reviewable panel/query changes over large wholesale rewrites.
