# Drift Detection Runbook

## Purpose

Detect Terraform drift between committed local state and live infrastructure before it accumulates into unsafe apply plans.

## Schedule

The repository convention documents scheduled drift detection on GitHub Actions Monday through Friday at 00:00 UTC. Use this runbook when that scheduled workflow fails, reports drift, or needs a manual rerun.

## Manual Check

```bash
# From repository root
make plan SVC=pve
make plan SVC=traefik
make plan SVC=elk
make plan SVC=archon
make plan SVC=cloudflare
make plan SVC=github
make plan SVC=slack
make plan SVC=gcp
```

Expected result: each plan exits successfully with no unexpected create, update, replace, or destroy actions.

## Triage

1. Open the scheduled GitHub Actions run for drift detection.
2. Identify the workspace that reported changes.
3. Review the plan output and classify the drift:
   - **Expected external change**: encode it in Terraform and open a PR.
   - **Unexpected manual change**: revert the live change or reconcile through Terraform.
   - **State mismatch**: follow [state-locking.md](state-locking.md) and [terraform-state-rollback.md](terraform-state-rollback.md).
4. Do not run local production `terraform apply`; deployments must go through CI/CD.

## Verification

After remediation, rerun the affected workspace plan through CI or `make plan SVC=<alias>` and confirm it is clean.
