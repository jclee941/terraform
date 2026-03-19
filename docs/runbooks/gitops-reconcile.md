# GitOps Reconcile Runbook
**Last Updated:** 2026-03-11

## Scope

Run the Proxmox-hosted GitOps controller and its GitHub reconcile entrypoint for
the safe workspace allowlist.

- Included in v1: `102-traefik/terraform`, `108-archon/terraform`, `301-github`
- Report-only in v1: `100-pve`, `modules/**`
- Out of scope: direct local `terraform apply`, Proxmox Tier-0 auto-apply, Kubernetes controllers

## Prerequisites

- LXC 109 (`gitops`) deployed and healthy
- Docker available inside `109-gitops`
- GitHub Actions enabled for the repository
- Existing apply workflows green for the target workspaces

## Manual Dry-run

```bash
gh workflow run gitops-reconcile.yml --ref master -f mode=dry-run

gh run watch --workflow gitops-reconcile.yml
```

Use dry-run to inspect which workspaces the GitHub entrypoint would dispatch.

## Targeted Reconcile

```bash
gh workflow run gitops-reconcile.yml --ref master -f mode=reconcile -f workspaces=traefik,archon

gh workflow run gitops-reconcile.yml --ref master -f mode=reconcile -f workspaces=github
```

The workflow dispatches the existing apply callers:

- `traefik-apply.yml`
- `archon-apply.yml`
- `github-apply.yml`

## Controller Reconcile

`109-gitops` runs a long-lived `gitops-agent` container that polls `master`
every 15 minutes, tracks the last dispatched commit, resolves changed safe
targets through `scripts/gitops-targets`, and dispatches `gitops-reconcile.yml`.

```bash
ssh root@192.168.50.100 'pct exec 109 -- docker compose -f /opt/gitops/docker-compose.yml logs --tail=100 gitops-agent'

ssh root@192.168.50.100 'pct exec 109 -- cat /var/lib/gitops-agent/state/last-result.json'
```

- This complements existing push-triggered apply workflows.
- This does not auto-dispatch `terraform-apply.yml` for `100-pve`.

## Verification

1. Confirm the `GitOps Reconcile` run succeeded.
2. Confirm each dispatched apply workflow succeeded.
3. Confirm `109-gitops` updated `/var/lib/gitops-agent/state/last-result.json`.
4. Run `make verify` if the change affected a reachable service.
5. Confirm no new drift issues were opened for the target workspace.

## Rollback

```bash
git revert <commit>
git push origin master

gh workflow run gitops-reconcile.yml --ref master -f mode=reconcile -f workspaces=traefik,archon,github
```

If the reconcile workflow itself is the problem, stop the `gitops-agent`
service in LXC 109, merge the revert, and use the existing apply workflows
directly until the controller logic is fixed.

## Local Helper Validation

```bash
GO111MODULE=off go test ./scripts/gitops-targets
GO111MODULE=off go test ./scripts/gitops-agent

env GO111MODULE=off go run ./scripts/gitops-targets --mode dry-run
```
