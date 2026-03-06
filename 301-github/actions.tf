locals {

  repository_actions_secrets_flat = {
    for item in flatten([
      for repo_name, secrets in nonsensitive(var.repository_actions_secrets) : [
        for secret_name in keys(secrets) : {
          key          = "${repo_name}:${secret_name}"
          repository   = repo_name
          secret_name  = secret_name
          secret_value = var.repository_actions_secrets[repo_name][secret_name]
        }
      ]
    ]) : item.key => item
  }

  repository_actions_variables_flat = {
    for item in flatten([
      for repo_name, variables in var.repository_actions_variables : [
        for variable_name, variable_value in variables : {
          key            = "${repo_name}:${variable_name}"
          repository     = repo_name
          variable_name  = variable_name
          variable_value = variable_value
        }
      ]
    ]) : item.key => item
  }
}


resource "github_actions_organization_secret" "organization" {
  for_each = var.manage_as_organization ? toset(keys(nonsensitive(var.organization_actions_secrets))) : toset([])

  secret_name     = each.value
  plaintext_value = var.organization_actions_secrets[each.value]
  visibility      = var.organization_secret_visibility
}

resource "github_actions_secret" "repositories" {
  for_each = local.repository_actions_secrets_flat

  repository      = each.value.repository
  secret_name     = each.value.secret_name
  plaintext_value = each.value.secret_value
}

resource "github_actions_organization_variable" "organization" {
  for_each = var.manage_as_organization ? var.organization_actions_variables : {}

  variable_name = each.key
  value         = each.value
  visibility    = var.organization_secret_visibility

  selected_repository_ids = var.organization_secret_visibility == "selected" ? [
    for repo_name in lookup(var.organization_variable_selected_repositories, each.key, []) :
    github_repository.repos[repo_name].repo_id
    if contains(keys(github_repository.repos), repo_name)
  ] : null
}

resource "github_actions_variable" "repositories" {
  for_each = local.repository_actions_variables_flat

  repository    = each.value.repository
  variable_name = each.value.variable_name
  value         = each.value.variable_value
}

resource "github_actions_variable" "infra_endpoints" {
  for_each = var.enable_infra_actions_variables ? local.infra_actions_variables : {}

  repository    = "terraform"
  variable_name = each.key
  value         = each.value
}
