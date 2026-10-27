# Cloudflare Production-Root Tests

The Cloudflare workspace test now lives in `300-cloudflare/terraform/tests/cloudflare_test.tftest.hcl` so Terraform evaluates it with the production root's provider and import semantics.

Run it from the repository root:

```bash
terraform -chdir=300-cloudflare/terraform test -filter=tests/cloudflare_test.tftest.hcl
```

This legacy directory retains migration documentation only; it is not a Terraform test root.
