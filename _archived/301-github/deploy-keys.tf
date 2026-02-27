locals {
  deploy_keys_flat = {
    for item in flatten([
      for repository, keys in nonsensitive(var.repository_deploy_keys) : [
        for title in keys(keys) : {
          key        = "${repository}:${title}"
          repository = repository
          title      = title
          public_key = var.repository_deploy_keys[repository][title].key
          read_only  = var.repository_deploy_keys[repository][title].read_only
        }
      ]
    ]) : item.key => item
  }
}

resource "github_repository_deploy_key" "keys" {
  for_each = local.deploy_keys_flat

  repository = each.value.repository
  title      = each.value.title
  key        = each.value.public_key
  read_only  = each.value.read_only
}
