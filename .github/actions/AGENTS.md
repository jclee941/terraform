# AGENTS: .github/actions - Composite Action Contracts

## OVERVIEW
Reusable composite actions shared across workflow domains. Keep action behavior stable and workflow-facing interfaces explicit.

## STRUCTURE
```text
.github/actions/
|- proxmox-import/    # Import existing Proxmox LXC/VM/firewall into TF state
|- terraform-setup/   # Install Terraform + run init in target workspace
`- notify-failure/    # Create/update failure issues with dedup behavior
```

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Terraform setup behavior | `terraform-setup/action.yml` | Input contract: version, working directory, init args. |
| Proxmox resource import | `proxmox-import/action.yml` | Idempotent import of 21 resources (11 LXC/VM + 10 firewall). Input: working-directory. |
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

- name: Import Proxmox Resources
  if: inputs.enable-proxmox-imports
  uses: ./.github/actions/proxmox-import
```

```bash
make lint
```
