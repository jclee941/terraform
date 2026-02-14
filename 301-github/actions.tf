locals {
  repository_actions_permissions = {
    for repo_name, repo_cfg in local.repositories :
    repo_name => {
      enabled              = !try(repo_cfg.archived, false)
      allowed_actions      = "selected"
      github_owned_allowed = true
      verified_allowed     = true
      patterns_allowed     = var.actions_allowed_patterns
    }
    if !try(repo_cfg.archived, false)
  }

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

resource "github_actions_organization_permissions" "organization" {
  for_each = var.manage_as_organization ? { default = true } : {}

  allowed_actions      = var.actions_allowed_actions
  enabled_repositories = var.actions_enabled_repositories

  dynamic "allowed_actions_config" {
    for_each = var.actions_allowed_actions == "selected" ? [1] : []
    content {
      github_owned_allowed = true
      verified_allowed     = true
      patterns_allowed     = var.actions_allowed_patterns
    }
  }

  dynamic "enabled_repositories_config" {
    for_each = var.actions_enabled_repositories == "selected" ? [1] : []
    content {
      repository_ids = [
        for repo_name in var.actions_enabled_repositories_selected :
        github_repository.repos[repo_name].repo_id
        if contains(keys(github_repository.repos), repo_name)
      ]
    }
  }
}

resource "github_actions_repository_permissions" "repositories" {
  for_each = local.repository_actions_permissions

  repository      = github_repository.repos[each.key].name
  enabled         = each.value.enabled
  allowed_actions = each.value.allowed_actions

  allowed_actions_config {
    github_owned_allowed = each.value.github_owned_allowed
    verified_allowed     = each.value.verified_allowed
    patterns_allowed     = each.value.patterns_allowed
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

resource "github_actions_runner_group" "groups" {
  for_each = var.manage_as_organization ? var.runner_groups : {}

  name                       = each.key
  visibility                 = each.value.visibility
  allows_public_repositories = each.value.allows_public_repositories
  restricted_to_workflows    = each.value.restricted_to_workflows
  selected_workflows         = each.value.selected_workflows
  selected_repository_ids = each.value.visibility == "selected" ? [
    for repo_name in each.value.selected_repositories :
    github_repository.repos[repo_name].repo_id
    if contains(keys(github_repository.repos), repo_name)
  ] : null
}
