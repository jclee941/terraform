terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

locals {
  rendered = {
    for name, config in var.template_files :
    name => templatefile(config.source, var.template_vars)
  }
}

resource "local_file" "rendered_configs" {
  for_each = local.rendered

  content  = each.value
  filename = "${var.output_dir}/${var.template_files[each.key].output}"
}
