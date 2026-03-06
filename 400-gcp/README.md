# 400-gcp: Google Cloud Platform

## 1. Service Overview

- **Service Name**: Google Cloud Platform (GCP)
- **Purpose**: Foundation workspace for GCP resource management via Terraform.
- **Current Status**: **Scaffold** — no resources deployed yet. 1Password lookup for GCP credentials is **disabled by default** until the `gcp` item exists; use variable overrides to enable when ready.

## 2. Configuration Files

<!-- BEGIN_TF_DOCS -->


## Requirements

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 7.22 |
| <a name="requirement_onepassword"></a> [onepassword](#requirement\_onepassword) | ~> 3.2 |

## Providers

## Providers

No providers.

## Resources

## Resources

No resources.

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_gcp_lookup"></a> [enable\_gcp\_lookup](#input\_enable\_gcp\_lookup) | Whether to fetch GCP credentials from 1Password (requires a 'gcp' item) | `bool` | `false` | no |
| <a name="input_gcp_credentials"></a> [gcp\_credentials](#input\_gcp\_credentials) | GCP service account key JSON override. Falls back to 1Password. | `string` | `""` | no |
| <a name="input_gcp_project"></a> [gcp\_project](#input\_gcp\_project) | GCP project ID override. Falls back to 1Password. | `string` | `""` | no |
| <a name="input_gcp_region"></a> [gcp\_region](#input\_gcp\_region) | GCP region for resources. | `string` | `"asia-northeast3"` | no |
| <a name="input_onepassword_vault_name"></a> [onepassword\_vault\_name](#input\_onepassword\_vault\_name) | 1Password vault name | `string` | `"homelab"` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_gcp_project"></a> [gcp\_project](#output\_gcp\_project) | Active GCP project ID |
| <a name="output_gcp_region"></a> [gcp\_region](#output\_gcp\_region) | Active GCP region |

<!-- END_TF_DOCS -->

## 3. Secrets

Managed via the shared `onepassword-secrets` module. Enable `enable_gcp_lookup = true` once a `gcp` item exists in 1Password; until then, provide overrides via variables or leave empty for scaffold-only runs.

| Key              | Source                 | Usage                    |
| ---------------- | ---------------------- | ------------------------ |
| `gcp_credentials` | 1Password `gcp` item  | GCP service account JSON |

## 4. CI/CD

| Workflow         | Trigger              | Action                     |
| ---------------- | -------------------- | -------------------------- |
| `gcp-plan.yml`   | PR targeting `master` | `terraform plan` on 400-gcp |
| `gcp-apply.yml`  | Push to `master`      | `terraform apply` on 400-gcp |
