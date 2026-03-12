# 109-gitops

GitOps controller LXC for GitHub-integrated reconcile dispatch.

## Runtime

- Host: LXC 109
- IP: `192.168.50.109`
- Mode: Docker Compose managed by `100-pve/lxc_configs.tf`
- Responsibility: pull repo state, remember the last dispatched commit, resolve
  safe workspaces, and dispatch `gitops-reconcile.yml`

## Scope

- Included: `301-github`, plus placeholder safe selectors already defined in
  `scripts/gitops-targets`
- Excluded: `100-pve`, `modules/**`, direct local `terraform apply`

## Operational Checks

```bash
ssh root@192.168.50.100 'pct exec 109 -- docker compose -f /opt/gitops/docker-compose.yml logs --tail=100 gitops-agent'
ssh root@192.168.50.100 'pct exec 109 -- docker ps --filter name=gitops-agent'
```
