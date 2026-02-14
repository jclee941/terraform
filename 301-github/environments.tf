locals {
  repository_environments_flat = {
    for item in flatten([
      for repository, environments in var.repository_environments : [
        for environment, cfg in environments : {
          key                    = "${repository}:${environment}"
          repository             = repository
          environment            = environment
          wait_timer             = try(cfg.wait_timer, 0)
          can_admins_bypass      = try(cfg.can_admins_bypass, true)
          prevent_self_review    = try(cfg.prevent_self_review, true)
          protected_branches     = try(cfg.protected_branches, true)
          custom_branch_policies = try(cfg.custom_branch_policies, false)
          reviewer_user_ids      = try(cfg.reviewer_user_ids, [])
          reviewer_team_ids      = try(cfg.reviewer_team_ids, [])
        }
      ]
    ]) : item.key => item
  }

  environment_secrets_flat = {
    for item in flatten([
      for repository, environments in nonsensitive(var.repository_environment_secrets) : [
        for environment, secrets in environments : [
          for secret_name in keys(secrets) : {
            key          = "${repository}:${environment}:${secret_name}"
            repository   = repository
            environment  = environment
            secret_name  = secret_name
            secret_value = var.repository_environment_secrets[repository][environment][secret_name]
          }
        ]
      ]
    ]) : item.key => item
  }

  environment_variables_flat = {
    for item in flatten([
      for repository, environments in var.repository_environment_variables : [
        for environment, vars in environments : [
          for variable_name, variable_value in vars : {
            key            = "${repository}:${environment}:${variable_name}"
            repository     = repository
            environment    = environment
            variable_name  = variable_name
            variable_value = variable_value
          }
        ]
      ]
    ]) : item.key => item
  }
}

resource "github_repository_environment" "environments" {
  for_each = local.repository_environments_flat

  repository          = each.value.repository
  environment         = each.value.environment
  wait_timer          = each.value.wait_timer
  can_admins_bypass   = each.value.can_admins_bypass
  prevent_self_review = each.value.prevent_self_review

  deployment_branch_policy {
    protected_branches     = each.value.protected_branches
    custom_branch_policies = each.value.custom_branch_policies
  }

  dynamic "reviewers" {
    for_each = length(each.value.reviewer_user_ids) > 0 || length(each.value.reviewer_team_ids) > 0 ? [1] : []
    content {
      users = each.value.reviewer_user_ids
      teams = each.value.reviewer_team_ids
    }
  }
}

resource "github_actions_environment_secret" "secrets" {
  for_each = local.environment_secrets_flat

  repository      = each.value.repository
  environment     = each.value.environment
  secret_name     = each.value.secret_name
  plaintext_value = each.value.secret_value
}

resource "github_actions_environment_variable" "variables" {
  for_each = local.environment_variables_flat

  repository    = each.value.repository
  environment   = each.value.environment
  variable_name = each.value.variable_name
  value         = each.value.variable_value
}
