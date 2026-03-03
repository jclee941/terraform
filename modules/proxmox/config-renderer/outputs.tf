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
