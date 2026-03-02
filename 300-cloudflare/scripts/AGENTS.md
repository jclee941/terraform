# AGENTS: 300-cloudflare/scripts - Cloudflare Automation Scripts

## OVERVIEW
Automation scripts for secret harvesting/sync/audit and Worker deployment support around the Cloudflare workspace.

## STRUCTURE
```
300-cloudflare/scripts/
├── collect.sh            # Harvest .env/.tfvars into Terraform-compatible values
├── sync.sh               # Push secret values to configured targets
├── audit.sh              # Compare inventory metadata vs target stores
├── generate-bindings.sh  # Build Wrangler secret binding declarations
├── deploy-worker.sh      # Disabled local deploy wrapper (CI-only policy)
├── BUILD.bazel
├── OWNERS
└── AGENTS.md
```

## WHERE TO LOOK
| Task | Script | Notes |
|------|--------|-------|
| Collect local secret values | `collect.sh` | Reads sibling `.env`/`.tfvars` inputs and emits Terraform-compatible output. |
| Sync to targets | `sync.sh` | Pushes secret values to CF/GitHub/Vault targets. |
| Inventory drift checks | `audit.sh` | Compares registry to target stores. |
| Worker secret bindings | `generate-bindings.sh` | Generates Wrangler binding declarations from inventory metadata. |
| Worker deployment wrapper | `deploy-worker.sh` | **DISABLED** — prints error and exits 1. Deploy via `worker-deploy.yml` CI workflow only. |
| Secret metadata source | `../inventory/secrets.yaml` | Registry SSoT for secret names/targets (no values). |
| Parent workspace policy | `../AGENTS.md` | Cloudflare workspace constraints and Terraform wiring. |
| Worker runtime counterpart | `../workers/AGENTS.md` | Worker boundary and runtime-specific rules. |

## COMMANDS
```bash
./300-cloudflare/scripts/collect.sh
./300-cloudflare/scripts/audit.sh
./300-cloudflare/scripts/sync.sh --dry-run
./300-cloudflare/scripts/generate-bindings.sh
./300-cloudflare/scripts/deploy-worker.sh  # expected failure (CI-only deploy)
```

## CONVENTIONS
- Keep `inventory/secrets.yaml` as metadata-only SSoT for secret targets.
- Keep secret value files ephemeral and gitignored.
- Keep scripts idempotent and `--dry-run` friendly for operational safety.

## ANTI-PATTERNS
- Do not commit generated secret value files or `.env` material.
- Do not bypass inventory metadata when adding new secrets.
- Do not log raw secret values during collect/sync operations.
