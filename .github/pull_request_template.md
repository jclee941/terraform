## Description

<!-- What does this PR do? Why is it needed? -->

Fixes #

## Workspace(s) Affected

<!-- Check all that apply -->

- [ ] `100-pve` (core infra)
- [ ] `modules/` (proxmox, shared)
- [ ] Service: <!-- e.g., 104-grafana, 105-elk -->
- [ ] External: <!-- e.g., 300-cloudflare, 301-github -->
- [ ] CI/CD (`.github/`)
- [ ] Documentation only

## Risk Tier

<!-- Based on auto-merge.yml classification -->

- [ ] **Critical** — 100-pve, modules, 300-cloudflare, 301-github, 102-traefik (manual merge required)
- [ ] **Medium** — 105-elk, 107-supabase, 108-archon, 112-mcphub (review required)
- [ ] **Low** — all other paths (auto-merge eligible)

## Pre-Merge Checklist

<!-- These align with pr-review.yml automated checks -->

- [ ] `terraform fmt -check` passes
- [ ] `terraform validate` passes
- [ ] YAML files are valid (yamllint)
- [ ] No hardcoded secrets, IPs outside `hosts.tf`, or `as any`
- [ ] `BUILD.bazel` and `OWNERS` present for new directories
- [ ] Docker Compose validates (if applicable)
- [ ] Module changes: impact analysis reviewed
- [ ] Tests pass (`make test` or relevant subset)

## Rollback Plan

<!-- How to revert if something goes wrong? -->

- [ ] Standard revert (`git revert` + `terraform apply`)
- [ ] Custom rollback steps: <!-- describe -->

## Screenshots / Plan Output

<!-- Paste relevant `terraform plan` output (redact secrets) -->

<details>
<summary>Terraform Plan</summary>

```
# paste plan output here
```

</details>
