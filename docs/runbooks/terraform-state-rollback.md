# Terraform State Rollback (GitHub Actions CI)

## Purpose

Restore a workspace state to the pre-apply snapshot captured in the same GitHub Actions pipeline when an apply fails.

## Scope

- Applies to GitHub Actions deploy stage jobs in `.github/workflows/`.
- Uses pre-apply backups stored in `gs://tfstate-homelab-backups`.
- Rollback remains **manual approval only**.

## Trigger Conditions

- `apply:all` failed for a workspace.
- State drift or partial apply is suspected after deploy failure.

## Preconditions

- Pipeline ran on default branch.
- Pre-apply backup object exists:
  - `gs://tfstate-homelab-backups/<workspace>-pre-apply-<pipeline_id>.tfstate`
- CI runner has `terraform` and `gsutil` available.

## Rollback Procedure

1. Open failed pipeline in GitLab.
2. In stage **deploy**, locate manual job `deploy:rollback` for the failed workspace matrix entry.
3. Run the job.

The rollback job executes:

```bash
cd "${TF_WORKING_DIR}"
terraform init -input=false
gsutil cp "gs://tfstate-homelab-backups/${TF_WORKSPACE_NAME}-pre-apply-${CI_PIPELINE_ID}.tfstate" ./pre-apply-state.tfstate
terraform state push pre-apply-state.tfstate
terraform plan -input=false -detailed-exitcode
```

## Verification

- Exit code `0`: rollback applied, state and config currently aligned.
- Exit code `2`: rollback applied, additional drift remains; investigate and re-run plan/apply workflow.
- Exit code `1`: rollback verification failed; treat as incident and escalate.

## Retention Policy

- Each pre-apply backup is tagged with metadata:
  - `x-goog-meta-retention-days: 30`
  - `x-goog-meta-retain-until: <RFC3339 timestamp>`
- Retention enforcement is expected from bucket lifecycle/policy aligned to 30 days.

## Emergency CLI Fallback (outside CI)

Use only when GitLab job execution is unavailable.

```bash
cd <workspace-dir>
terraform init -input=false
gsutil cp "gs://tfstate-homelab-backups/<workspace>-pre-apply-<pipeline_id>.tfstate" ./pre-apply-state.tfstate
terraform state push pre-apply-state.tfstate
terraform plan -input=false
```

## Safety Notes

- Do not run automatic rollback on apply failure.
- Do not delete pre-apply objects during incident response.
- Keep rollback actions auditable through pipeline job history.
