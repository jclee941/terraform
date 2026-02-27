locals {
  team_memberships_flat = {
    for item in flatten([
      for team_key, memberships in var.team_memberships : [
        for username, role in memberships : {
          key      = "${team_key}:${username}"
          team_key = team_key
          username = username
          role     = role
        }
      ]
    ]) : item.key => item
  }

  team_repository_access_flat = {
    for item in flatten([
      for team_key, repositories in var.team_repository_access : [
        for repo_name, permission in repositories : {
          key        = "${team_key}:${repo_name}"
          team_key   = team_key
          repository = repo_name
          permission = permission
        }
      ]
    ]) : item.key => item
  }
}

resource "github_team" "teams" {
  for_each = var.manage_as_organization ? var.teams : {}

  name                 = each.value.name
  description          = each.value.description
  privacy              = each.value.privacy
  notification_setting = each.value.notification_setting
}

resource "github_team_membership" "memberships" {
  for_each = var.manage_as_organization ? local.team_memberships_flat : {}

  team_id  = github_team.teams[each.value.team_key].id
  username = each.value.username
  role     = each.value.role
}

resource "github_team_repository" "repository_access" {
  for_each = var.manage_as_organization ? local.team_repository_access_flat : {}

  team_id    = github_team.teams[each.value.team_key].id
  repository = each.value.repository
  permission = each.value.permission
}
