data "github_user" "owner" {
  username = var.github_owner
}

data "github_repository" "existing" {
  for_each = local.known_repositories

  full_name = "${var.github_owner}/${each.value}"
}
