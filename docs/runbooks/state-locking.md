# State Locking Runbook

**Last Updated:** 2026-02-18

## Current State Backend

All workspaces use Cloudflare R2 via the S3-compatible backend:

| Workspace | State Key |
|-----------|-----------|
| 100-pve | `100-pve/terraform.tfstate` |
| 300-cloudflare | `300-cloudflare/terraform.tfstate` |
| 301-github | `301-github/terraform.tfstate` |
| 102-traefik | `102-traefik/terraform.tfstate` |
| 104-grafana | `104-grafana/terraform.tfstate` |
| 105-elk | `105-elk/terraform.tfstate` |
| 108-archon | `108-archon/terraform.tfstate` |

Bucket: `jclee-tf-state` (R2, endpoint `*.r2.cloudflarestorage.com`).

## Limitation: No Native State Locking

Cloudflare R2 does **not** support DynamoDB-style state locking. The S3 backend's `dynamodb_table` parameter is not available with R2.

**Risk**: Concurrent `terraform apply` runs against the same workspace can corrupt state.

## Current Mitigations

1. **CI serialization**: GitHub Actions workflows use `concurrency` groups per workspace, ensuring only one plan/apply runs at a time per stack.
2. **Single operator**: Homelab is single-operator, reducing concurrent access risk.
3. **Plan-then-apply**: All CI workflows use `terraform plan -out=tfplan` followed by gated `terraform apply tfplan`, preventing interleaved operations.

## Resolving State Conflicts

If state corruption occurs (e.g., two applies ran simultaneously):

1. **Stop all operations**: Cancel any running CI workflows.
2. **Download current state**:
   ```bash
   cd <workspace-dir>
   terraform state pull > state-backup.json
   ```
3. **Inspect the state** for resource duplicates or missing entries:
   ```bash
   terraform state list | sort | uniq -d
   ```
4. **Recover from R2 versioning** (if enabled):
   ```bash
   # List object versions
   aws s3api list-object-versions \
     --bucket jclee-tf-state \
     --prefix "<workspace>/terraform.tfstate" \
     --endpoint-url https://<account-id>.r2.cloudflarestorage.com
   ```
5. **Restore a known-good version**:
   ```bash
   terraform state push state-backup.json
   ```
6. **Verify** with `terraform plan` — expect zero changes if state is correct.

## Future: Adding State Locking

To add locking, choose one of:

| Option | Effort | Notes |
|--------|--------|-------|
| Migrate to Terraform Cloud / HCP | Low | Built-in locking, free tier covers 5 workspaces |
| Add DynamoDB (AWS) | Medium | Requires AWS account, `dynamodb_table` in backend config |
| Use `consul` backend | Medium | Self-hosted Consul cluster required |
| Terraform 1.10+ `use_lockfile` | Low | File-based locking if/when R2 supports conditional writes |

For this homelab, the CI concurrency groups provide adequate protection. Revisit if the team grows beyond a single operator.
