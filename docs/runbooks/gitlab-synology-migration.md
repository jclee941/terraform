# GitLab Migration Runbook — 215-synology
**Last Updated:** 2026-03-28

## Scope

Deploy and stabilize GitLab CE on Synology NAS, then migrate CI/CD from GitHub Actions to GitLab CI.

## Prerequisites

- Synology NAS reachable at `192.168.50.215:5001` from GitLab runner network.
- GitLab runner with tags: `synology`, `terraform`.
- 1Password Connect server reachable from runner.
- If previous GitLab data exists on `/volume1/docker/gitlab`, start from `17.8.x` first, then upgrade to newer versions.

## Required GitLab CI Variables

Set as **Protected + Masked** (except host URLs):

- `OP_CONNECT_HOST`
- `OP_CONNECT_TOKEN`
- `TF_VAR_synology_host` (optional override, default already `https://192.168.50.215:5001`)
- `TF_VAR_synology_user`
- `TF_VAR_synology_password`

> Current `215-synology` checks fail closed when Synology credentials are missing.
> Set both `TF_VAR_synology_user` and `TF_VAR_synology_password` in GitLab CI variables.

## Phase 1: GitLab Deployment & Stabilization (COMPLETE)

1. Enable GitLab project in `215-synology/terraform.tfvars`:
   - `enable_gitlab_project = true`
   - `gitlab_external_url = "http://192.168.50.215:8929"`
2. Run `terraform apply` to provision GitLab CE container on Synology.
3. Verify container health: `docker inspect --format='{{.State.Health.Status}}' gitlab` → `healthy`.
4. Verify internal subsystems: `gitlab-rake gitlab:check SANITIZE=true` → all OK.
5. Verify HTTP endpoint: `curl -I http://192.168.50.215:8929/users/sign_in` → `200`.
6. Verify API: `curl --header "PRIVATE-TOKEN: <PAT>" http://192.168.50.215:8929/api/v4/version` → version response.
7. Verify git operations: clone → modify → commit → push round-trip via HTTP.
8. Verify restart durability: `docker restart gitlab` → healthy, data intact.

## Phase 2: GitLab CI Migration (IN PROGRESS)

### Migrated Workspaces

The following workspaces have been migrated to GitLab CI:

| Workspace | Status |
|-----------|--------|
| `215-synology` | Migrated |
| `310-safetywallet` | Migrated |

### Excluded Workspaces

The following workspaces are NOT migrating to GitLab CI:

| Workspace | Reason |
|-----------|--------|
| `301-github` | Workspace deleted - GitHub repo management no longer needed |
| `320-slack` | Minimal implementation, no Terraform resources, stays on GitHub Actions |


### GitHub Actions Migration Scope

**Terraform CI/CD migrated to GitLab CI:**
- `_archon-plan.yml`, `_cloudflare-plan.yml`, `_elk-plan.yml`, `_gcp-plan.yml`, `_grafana-plan.yml`, `_traefik-plan.yml` — disabled (`if: false`)

**Remaining in GitHub Actions (operational workflows):**
- `runner-health-check.yml` — GitLab runner health monitoring
- `terraform-drift.yml` — Infrastructure drift detection (scheduled)
- `synology-health-check.yml` — Synology NAS health checks
- `credential-rotation.yml` — Secret rotation automation
- `security-scan.yml`, `secret-audit.yml` — Security scanning

These operational workflows remain in GitHub Actions because GitLab CI is focused on Terraform deployment (validate/plan/apply) only. Health checks, drift detection, and security scanning continue to run via GitHub Actions.


### 2a. Infrastructure (DONE)

1. Add repository-level `.gitlab-ci.yml` with `validate -> plan -> apply` pipeline (GitLab CI currently implements core Terraform workflow; operational stages like preflight and verify remain in GitHub Actions for health checks and drift detection).
2. Add Container Registry support to GitLab Omnibus config (`registry_external_url`, port `5050`).
3. Add GitLab Runner container project to `215-synology/main.tf` (Docker executor, `gitlab/gitlab-runner:alpine`).
4. Add runner token check block in `checks.tf` (fail-closed when `TF_VAR_gitlab_runner_token` empty).
5. Update `hosts.tf` synology entry: roles `["nas", "storage", "gitlab", "ci"]`, ports `gitlab_http=8929`, `gitlab_ssh=2224`, `gitlab_registry=5050`.
6. Register GitLab MCP server (`@zereight/mcp-gitlab`) in `112-mcphub/mcp_servers.json` (port 8082, stdio).
7. Disable GitHub Actions workflow `synology-apply.yml` (`if: false`).

### 2b. Activation (PENDING — manual steps)

1. Set `enable_gitlab_registry = true` and `enable_gitlab_runner = true` in `215-synology/terraform.tfvars`.
2. Run `terraform apply` to provision runner and registry containers.
3. Register GitLab runner:
   ```bash
   docker exec gitlab-runner gitlab-runner register \
     --non-interactive \
     --url "http://192.168.50.215:8929" \
     --token "${RUNNER_TOKEN}" \
     --executor "docker" \
     --docker-image "alpine:latest" \
     --docker-privileged \
     --description "synology-runner" \
     --tag-list "synology,terraform,docker"
   ```
4. Add required CI variables in GitLab project settings (see Required GitLab CI Variables above).
5. Push a branch changing `215-synology/**` to trigger `validate` and `plan` jobs.
6. Merge to `main`/`master` to trigger `apply` and `verify` jobs.
7. Verify Container Registry: `curl http://192.168.50.215:5050/v2/` returns `{}` or auth challenge.

## Validation Checklist

- `validate:synology` passes (`terraform fmt -check`, `terraform validate`).
- `plan:synology` produces `tfplan` artifact.
- `apply:synology` succeeds on `main` branch.
- Verify GitLab sign-in endpoint responds: `GET /users/sign_in`.
- `validate:synology` passes (`terraform fmt -check`, `terraform validate`).
- `plan:synology` produces `tfplan` and `plan_output.txt` artifacts.
- `apply:synology` succeeds on `main` branch.
- `verify:synology` confirms non-empty Terraform outputs and checks `gitlab_project_enabled = true`.
- `verify:synology` confirms GitLab sign-in endpoint responds: `GET /users/sign_in`.
- Optional migration proof in CI: set `GITLAB_MIGRATION_PAT` and `GITLAB_MIGRATION_PROJECT`, then verify API project lookup succeeds.

## Runtime Troubleshooting: Project Creation Fails with Disk Conflict

Symptom:

- GitLab UI/API project creation fails with:
  - `There is already a repository with that name on disk`
  - `uncaught throw :abort`

Diagnostic sequence (inside GitLab container):

1. Check configured repository storage path:
   - `gitlab-rails runner 'puts Gitlab.config.repositories.storages.to_h'`
2. Confirm target namespace/path and inspect existing directories:
   - `ls -la /var/opt/gitlab/git-data/repositories`
   - `find /var/opt/gitlab/git-data/repositories -maxdepth 3 -type d -name "<project>.git"`
3. Verify ownership/permissions:
   - `chown -R git:git /var/opt/gitlab/git-data/repositories`
   - `gitlab-rake gitlab:check SANITIZE=true`

Safe remediation sequence:

1. Stop writes to target namespace briefly (maintenance window).
2. Move only conflicting stale repository directories to quarantine path (do not delete immediately).
3. Re-run `gitlab-rake gitlab:check SANITIZE=true`.
4. Retry project creation via API:
   - `curl --header "PRIVATE-TOKEN: <PAT>" --data "name=<project>&path=<project>&initialize_with_readme=true" "http://192.168.50.215:8929/api/v4/projects"`
5. If creation succeeds, remove quarantine directory after backup retention window.

Evidence capture for migration completion:

- `curl -I http://192.168.50.215:8929/users/sign_in` returns `200` or `302`.
- `curl --header "PRIVATE-TOKEN: <PAT>" "http://192.168.50.215:8929/api/v4/projects?search=<project>"` returns at least one project object.
- Optional SSH proof: `ssh -T -p 2224 git@192.168.50.215` reaches GitLab shell banner.

## Rollback

1. Revert the offending commit.
2. Push revert to `main`.
3. GitLab pipeline re-applies previous Terraform state.
4. If GitLab CI is broken, re-enable `synology-apply.yml` by removing `if: false` and trigger via `workflow_dispatch`.
