locals {
  codeowners_repositories = {
    for repo_name, repo_cfg in local.repositories :
    repo_name => repo_cfg
    if var.enable_codeowners_management && !try(repo_cfg.archived, false) && contains(["strict", "standard"], try(repo_cfg.protection, "minimal"))
  }
}

resource "github_repository_file" "codeowners" {
  for_each = local.codeowners_repositories

  repository          = github_repository.repos[each.key].name
  branch              = try(each.value.default_branch, "main")
  file                = "CODEOWNERS"
  content             = "# Auto-managed by Terraform (301-github)\n* @${var.github_owner}\n"
  commit_message      = "chore: update CODEOWNERS [terraform-managed]"
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [commit_message, commit_author, commit_email]
  }
}
