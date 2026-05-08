# Module Release Process

This repository versions reusable Terraform modules with Git tags in the format:

`modules/<module-path>/v<MAJOR>.<MINOR>.<PATCH>`

Example: `modules/proxmox/lxc/v1.0.0`

## Release workflow

1. Update module code under `modules/`.
2. Validate in at least one consuming workspace:
   - `terraform init`
   - `terraform validate`
   - `terraform plan`
3. Write release notes in the Git tag message or create a GitHub release.
4. Create module tag(s):
   - `git tag modules/proxmox/lxc/vX.Y.Z`
5. Push tags to remote:
   - `git push origin --tags`
6. Update consumer `source` references to the new tag gradually.
7. Re-run workspace validation after each consumer upgrade.

## Consumer source format

Use Git source URLs pinned to module-specific refs:

```hcl
module "example" {
  source = "git::https://github.com/qws941/terraform.git//modules/proxmox/lxc?ref=modules/proxmox/lxc/v1.0.0"
}
```

## Versioning policy

- `MAJOR`: breaking input/output behavior changes.
- `MINOR`: backward-compatible features.
- `PATCH`: backward-compatible fixes/documentation/internal improvements.
