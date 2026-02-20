# State Locking Runbook

**Last Updated:** 2026-02-19

## Current State Backend

All workspaces use local backend (state files stored alongside each workspace):

| Workspace | State File |
|-----------|------------|
| 100-pve | `100-pve/terraform.tfstate` |
| 102-traefik | `102-traefik/terraform/terraform.tfstate` |
| 104-grafana | `104-grafana/terraform/terraform.tfstate` |
| 105-elk | `105-elk/terraform/terraform.tfstate` |
| 108-archon | `108-archon/terraform/terraform.tfstate` |
| 300-cloudflare | `300-cloudflare/terraform.tfstate` |
| 301-github | `301-github/terraform.tfstate` |

Init: `terraform init` (no `-backend-config` needed).

## Limitation: No Native State Locking

Local backend does **not** support state locking. There is no lock file mechanism to prevent concurrent writes.

**Risk**: Concurrent `terraform apply` runs against the same workspace can corrupt state.

## Current Mitigations

1. **CI serialization**: GitHub Actions workflows use `concurrency` groups per workspace, ensuring only one plan/apply runs at a time per stack.
2. **Single operator**: homelab is single-operator, reducing concurrent access risk.
3. **Plan-then-apply**: All CI workflows use `terraform plan -out=tfplan` followed by gated `terraform apply tfplan`, preventing interleaved operations.

## Resolving State Conflicts

If state corruption occurs (e.g., two applies ran simultaneously):

1. **Stop all operations**: Cancel any running CI workflows.
2. **Backup current state**:
   ```bash
   cd <workspace-dir>
   cp terraform.tfstate terraform.tfstate.backup
   ```
3. **Inspect the state** for resource duplicates or missing entries:
   ```bash
   terraform state list | sort | uniq -d
   ```
4. **Recover from backup**:
   ```bash
   # Restore from the most recent known-good backup
   cp terraform.tfstate.backup terraform.tfstate
   ```
5. **Verify** with `terraform plan` — expect zero changes if state is correct.

## Future: Adding State Locking

To add locking, choose one of:

| Option | Effort | Notes |
|--------|--------|-------|
| Migrate to Terraform Cloud / HCP | Low | Built-in locking, free tier covers 5 workspaces |
| Use `consul` backend | Medium | Self-hosted Consul cluster required |
| Use S3 + DynamoDB (AWS) | Medium | Requires AWS account |

For this homelab, the CI concurrency groups provide adequate protection. Revisit if the team grows beyond a single operator.
