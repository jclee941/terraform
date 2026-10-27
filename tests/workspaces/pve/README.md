# PVE Production-Root Tests

The PVE workspace test now lives in `100-pve/terraform/tests/pve_test.tftest.hcl` so Terraform evaluates it with the production root's provider and import semantics.

Run it from the repository root:

```bash
terraform -chdir=100-pve/terraform test -filter=tests/pve_test.tftest.hcl
```

This legacy directory retains migration documentation only; it is not a Terraform test root.
