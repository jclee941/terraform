# AGENTS: .github/actions - Composite Action Contracts

## OVERVIEW
Reusable composite actions shared across workflow domains. Keep action behavior stable and workflow-facing interfaces explicit.

## STRUCTURE
```text
.github/actions/
|- terraform-setup/   # Install Terraform + run init in target workspace
`- notify-failure/    # Create/update failure issues with dedup behavior
```

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Terraform setup behavior | `terraform-setup/action.yml` | Input contract: version, working directory, init args. |
| Failure issue behavior | `notify-failure/action.yml` | Dedup logic and issue/comment update path. |

## CONVENTIONS
- Pin third-party action refs to full commit SHAs inside composite step definitions.
- Keep composite action inputs backward-compatible for workflow callers.
- Keep side effects idempotent (dedup instead of issue spam).

## ANTI-PATTERNS
- Do not hardcode secrets in action definitions.
- Do not duplicate caller workflow logic inside action internals.
- Do not change input names without updating all calling workflows.

## COMMANDS
```yaml
# .github/workflows/<workflow>.yml
- name: Setup Terraform
  uses: ./.github/actions/terraform-setup

- name: Notify Failure
  if: failure()
  uses: ./.github/actions/notify-failure
```

```bash
make lint
```
