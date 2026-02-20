# AGENTS: 300-cloudflare/scripts - Cloudflare Automation Scripts

## OVERVIEW
Automation scripts for secret harvesting/sync/audit and Worker deployment support around the Cloudflare workspace.

## WHERE TO LOOK
| Task | Script | Notes |
|------|--------|-------|
| Collect local secret values | `collect.sh` | Reads sibling `.env`/`.tfvars` inputs and emits Terraform-compatible output. |
| Sync to targets | `sync.sh` | Pushes secret values to CF/GitHub/Vault targets. |
| Inventory drift checks | `audit.sh` | Compares registry to target stores. |
| Worker secret bindings | `generate-bindings.sh` | Generates Wrangler binding declarations from inventory metadata. |
| Worker deployment wrapper | `deploy-worker.sh` | Deployment orchestration helper for worker lifecycle. |

## CONVENTIONS
- Keep `inventory/secrets.yaml` as metadata-only SSoT for secret targets.
- Keep secret value files ephemeral and gitignored.
- Keep scripts idempotent and `--dry-run` friendly for operational safety.

## ANTI-PATTERNS
- Do not commit generated secret value files or `.env` material.
- Do not bypass inventory metadata when adding new secrets.
- Do not log raw secret values during collect/sync operations.
