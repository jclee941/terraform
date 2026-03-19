# AGENTS: 105-elk/terraform

## OVERVIEW

Nested elasticstack provider workspace. Manages ILM policies, index templates, Kibana space/data views, and snapshot repository for the ELK service.

## STRUCTURE

```text
105-elk/terraform/
├── main.tf          # Service registry, ILM policies, templates, Kibana objects
├── onepassword.tf   # Provider auth via shared secret module
├── checks.tf        # Workspace validation checks
├── outputs.tf       # Downstream IDs and names
└── README.md        # terraform-docs output
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Service registry and ILM tiers | `main.tf` | `log_services`, critical/ephemeral pattern derivation, ILM resources. |
| Provider auth | `onepassword.tf` | Pulls Elastic credentials from shared secret module. |
| Outputs for downstream consumers | `outputs.tf` | Template names, policy names, Kibana IDs. |
| Validation tests | `tests/workspaces/elk/elk_test.tftest.hcl` | Mock-provider validation for workspace contract. |

## CONVENTIONS

- `main.tf` is the source of truth for service-to-tier mapping and index-template priority.
- Keep the tier model coherent: standard 30d, critical 90d, ephemeral 7d.
- Provider auth stays 1Password-backed; tfvars overrides are break-glass only.
- Local apply is disabled; use `make plan SVC=elk` and CI/CD for apply.

## ANTI-PATTERNS

- Do not create Kibana spaces, data views, or ILM policies manually when Terraform owns them.
- Do not rename `log_services` keys without updating Logstash routing, Grafana dashboards, and tests.
- Do not hardcode provider credentials or disable auth expectations in this workspace.

## COMMANDS

```bash
make plan SVC=elk
make validate SVC=elk
cd tests/workspaces/elk && terraform init -backend=false && terraform test
```
