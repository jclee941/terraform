output "repository_html_urls" {
  description = "Managed repository HTML URLs by repository name."
  value = {
    for repo_name, repo in github_repository.repos :
    repo_name => repo.html_url
  }
}

output "repository_clone_urls" {
  description = "Managed repository clone URLs (HTTPS and SSH)."
  value = {
    for repo_name, repo in github_repository.repos :
    repo_name => {
      ssh   = repo.ssh_clone_url
      https = repo.http_clone_url
    }
  }
}

output "repository_webhook_ids" {
  description = "Repository webhook IDs keyed by repo:webhook_name."
  value = {
    for key, webhook in github_repository_webhook.webhooks :
    key => webhook.id
  }
}

output "team_ids" {
  description = "Team IDs keyed by team key."
  value = {
    for team_key, team in github_team.teams :
    team_key => team.id
  }
}
