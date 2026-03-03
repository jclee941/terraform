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
