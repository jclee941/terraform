# AGENTS: tests/workspaces/pve — PVE Workspace Tests

## OVERVIEW
Terraform workspace tests for `100-pve` infrastructure provisioning.

## STRUCTURE
```
100-pve/terraform/tests/
└── pve_test.tftest.hcl    # Production-root test file
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Test setup and assertions | `100-pve/terraform/tests/pve_test.tftest.hcl` | Runs in the production root with mocked providers. |

## CONVENTIONS
- Use `terraform test` framework
- Mock providers where possible
- Test plan, not apply

## ANTI-PATTERNS
- NEVER run real applies in tests
- NEVER test against production state

## COMMANDS
```bash
terraform -chdir=100-pve/terraform test -filter=tests/pve_test.tftest.hcl
make test-workspace
```
