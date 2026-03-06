# 400-gcp: Google Cloud Platform

## 1. Service Overview

- **Service Name**: Google Cloud Platform (GCP)
- **Purpose**: Foundation workspace for GCP resource management via Terraform.
- **Current Status**: **Scaffold** — provider and 1Password integration configured, no resources deployed yet.

## 2. Configuration Files

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 7.22 |
| <a name="requirement_onepassword"></a> [onepassword](#requirement\_onepassword) | ~> 3.2 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_onepassword_secrets"></a> [onepassword\_secrets](#module\_onepassword\_secrets) | ../modules/shared/onepassword-secrets | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_gcp_credentials"></a> [gcp\_credentials](#input\_gcp\_credentials) | GCP service account key JSON override. Falls back to 1Password. | `string` | `""` | no |
| <a name="input_gcp_project"></a> [gcp\_project](#input\_gcp\_project) | GCP project ID override. Falls back to 1Password. | `string` | `""` | no |
| <a name="input_gcp_region"></a> [gcp\_region](#input\_gcp\_region) | GCP region for resources. | `string` | `"asia-northeast3"` | no |
| <a name="input_onepassword_vault_name"></a> [onepassword\_vault\_name](#input\_onepassword\_vault\_name) | 1Password vault name | `string` | `"homelab"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_gcp_project"></a> [gcp\_project](#output\_gcp\_project) | Active GCP project ID |
| <a name="output_gcp_region"></a> [gcp\_region](#output\_gcp\_region) | Active GCP region |
<!-- END_TF_DOCS -->

## 3. Secrets

Managed via the shared `onepassword-secrets` module with `enable_gcp = true`.

| Key              | Source                 | Usage                    |
| ---------------- | ---------------------- | ------------------------ |
| `gcp_credentials` | 1Password `gcp` item  | GCP service account JSON |

## 4. CI/CD

| Workflow         | Trigger              | Action                     |
| ---------------- | -------------------- | -------------------------- |
| `gcp-plan.yml`   | PR targeting `master` | `terraform plan` on 400-gcp |
| `gcp-apply.yml`  | Push to `master`      | `terraform apply` on 400-gcp |
