# AGENTS: modules/elasticstack

## OVERVIEW
Reusable Terraform modules for Elasticsearch lifecycle and index-template resources used by the ELK workspace.

## STRUCTURE
```text
modules/elasticstack/
├── ilm_policy/      # `elasticstack_elasticsearch_index_lifecycle`
└── index_template/  # `elasticstack_elasticsearch_index_template`
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| ILM policy behavior | `ilm_policy/main.tf` | Hot priority plus delete phase. |
| ILM inputs/outputs | `ilm_policy/{variables,outputs}.tf` | Name, priority, retention age. |
| Index template behavior | `index_template/main.tf` | Template settings/mappings for service indices. |
| ELK consumer workspace | `../../105-elk/terraform/AGENTS.md` | Provider auth and concrete service index wiring. |

## CONVENTIONS
- Keep module behavior generic; service-specific retention tiers belong in `105-elk/terraform`.
- Preserve provider version compatibility with `elastic/elasticstack >= 0.13`.
- Keep ILM defaults explicit in variables rather than hidden inside workspace locals.
- Treat mappings and settings as interface contracts; update tests when output shape changes.

## ANTI-PATTERNS
- Do not disable ILM or create unbounded index growth paths.
- Do not put Elasticsearch credentials, URLs, or workspace-specific secrets in these modules.
- Do not use Kibana Console changes as a substitute for Terraform-managed templates.
