# AGENTS: 104-grafana/dashboards

## OVERVIEW

Dashboard JSON files in this directory are the source of truth for Grafana dashboard content deployed through Terraform.

## STRUCTURE

```text
104-grafana/dashboards/
├── *.json        # Dashboard definitions (UID/title stable)
└── README.md     # Inventory and usage notes
```

## WHERE TO LOOK

| Task                            | Location                           | Notes                                       |
| ------------------------------- | ---------------------------------- | ------------------------------------------- |
| Dashboard source edits          | `104-grafana/dashboards/*.json`    | Edit panel/query/layout JSON directly.      |
| Dashboard catalog and ownership | `104-grafana/dashboards/README.md` | Keep list and usage guidance aligned.       |
| Terraform wiring                | `104-grafana/terraform/`           | Provider applies dashboard JSON to Grafana. |
| Service-level constraints       | `104-grafana/AGENTS.md`            | Parent scope for stack-wide rules.          |

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
