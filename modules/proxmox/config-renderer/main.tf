variable "template_vars" {
  description = "Variables for rendering templates"
  type        = any
}

variable "template_files" {
  description = "Map of config name to template source path and output filename"
  type = map(object({
    source = string
    output = string
  }))
}

variable "output_dir" {
  description = "Directory to write rendered configs"
  type        = string
  default     = "../../configs/rendered"
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

output "rendered_configs" {
  description = "Map of rendered config content"
  value       = local.rendered
}

output "rendered_files" {
  description = "Paths to rendered config files"
  value = {
    for name, _ in local.rendered :
    name => try(local_file.rendered_configs[name].filename, "")
  }
}
