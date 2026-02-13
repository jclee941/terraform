locals {
  inventory = yamldecode(file("${path.module}/inventory/secrets.yaml"))

  all_secrets = try(local.inventory.secrets, [])

  github_repo_map   = try(local.inventory.github.repos, {})
  github_repo_names = sort(values(local.github_repo_map))

  github_secret_entries = flatten([
    for secret in local.all_secrets : [
      for repo_alias in try(secret.targets.github, []) : {
        key         = "${repo_alias}:${secret.name}"
        repository  = lookup(local.github_repo_map, repo_alias, repo_alias)
        secret_name = secret.name
      }
    ]
  ])

  github_secrets = {
    for entry in local.github_secret_entries : entry.key => entry
  }

  vault_secret_entries = [
    for secret in local.all_secrets : {
      path       = try(secret.targets.vault, null)
      secret_key = secret.name
    }
    if try(secret.targets.vault, null) != null
  ]

  vault_paths = sort(distinct([
    for entry in local.vault_secret_entries : entry.path
  ]))

  vault_secrets = {
    for path in local.vault_paths : path => sort([
      for entry in local.vault_secret_entries : entry.secret_key
      if entry.path == path
    ])
  }

  cf_store_secrets = sort([
    for secret in local.all_secrets : secret.name
    if try(secret.targets.cf_store, false) == true
  ])

  total_secrets_count = length(local.all_secrets)
}
