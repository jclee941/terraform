# AGENTS: tests/workspaces/grafana — Grafana Workspace Tests

## OVERVIEW
Terraform workspace tests for `104-grafana` dashboard and datasource provisioning.

## STRUCTURE
```
grafana/
├── main.tf                # Test workspace configuration
└── .terraform/            # Provider cache
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Datasource tests | `main.tf` | Validate datasource YAML |
| Dashboard tests | `main.tf` | Validate dashboard JSON |

## CONVENTIONS
- Test provisioning file syntax
- Validate JSON structure
- Check datasource connectivity

## ANTI-PATTERNS
- NEVER use real credentials in tests
- NEVER modify production dashboards
