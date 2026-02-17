# Config Renderer Module

Central template rendering pipeline. Takes `.tftpl` templates and a
variable map (including the hosts inventory), renders them via
`templatefile()`, and writes output to `tf-configs/` directories.

<!-- BEGIN_TF_DOCS -->


## Requirements

## Requirements

No requirements.

## Providers

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | n/a |

## Resources

## Resources

| Name | Type |
|------|------|
| [local_file.rendered_configs](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_template_files"></a> [template\_files](#input\_template\_files) | Map of config name to template source path and output filename | <pre>map(object({<br/>    source = string<br/>    output = string<br/>  }))</pre> | n/a | yes |
| <a name="input_template_vars"></a> [template\_vars](#input\_template\_vars) | Variables for rendering templates | `any` | n/a | yes |
| <a name="input_output_dir"></a> [output\_dir](#input\_output\_dir) | Directory to write rendered configs | `string` | `"../../configs/rendered"` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_rendered_configs"></a> [rendered\_configs](#output\_rendered\_configs) | Map of rendered config content |
| <a name="output_rendered_files"></a> [rendered\_files](#output\_rendered\_files) | Paths to rendered config files |

<!-- END_TF_DOCS -->
