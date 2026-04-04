# AGENTS: tests/workspaces/gcp — GCP Workspace Tests

## OVERVIEW
Terraform workspace tests for `400-gcp` Google Cloud Platform resources.

## STRUCTURE
```
gcp/
├── main.tf                # Test workspace configuration
└── .terraform/            # Provider cache
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Resource tests | `main.tf` | Validate GCP resource configs |
| IAM tests | `main.tf` | Validate IAM bindings |

## CONVENTIONS
- Use GCP provider in mock mode
- Test resource validation
- Validate IAM policies

## ANTI-PATTERNS
- NEVER create real GCP resources in tests
- NEVER use production service accounts
