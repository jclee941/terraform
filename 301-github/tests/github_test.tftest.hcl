# GitHub Workspace Variable Validation Tests
# Workspace: 301-github (GitHub Org, Repos, Teams, Branch Protection)
# Run: terraform -chdir=301-github test
# Note: Tests live under 301-github/tests/ (Terraform default test dir)
# because 301-github/import.tf uses import blocks (root module only).

mock_provider "github" {}

override_data {
  target = data.terraform_remote_state.infra
  values = {
    outputs = {
      host_inventory = {}
      service_urls   = {}
    }
  }
}

# --- github_owner validation (GitHub username regex, max 39 chars) ---

run "test_invalid_github_owner_starts_with_hyphen" {
  command = plan

  variables {
    github_token = "test-token-placeholder"
    github_owner = "-invalid"
  }

  expect_failures = [
    var.github_owner,
  ]
}

run "test_invalid_github_owner_ends_with_hyphen" {
  command = plan

  variables {
    github_token = "test-token-placeholder"
    github_owner = "invalid-"
  }

  expect_failures = [
    var.github_owner,
  ]
}

run "test_invalid_github_owner_too_long" {
  command = plan

  variables {
    github_token = "test-token-placeholder"
    github_owner = "abcdefghijklmnopqrstuvwxyz1234567890abcd" # pragma: allowlist secret
  }

  expect_failures = [
    var.github_owner,
  ]
}

run "test_invalid_github_owner_underscore" {
  command = plan

  variables {
    github_token = "test-token-placeholder"
    github_owner = "invalid_name"
  }

  expect_failures = [
    var.github_owner,
  ]
}

# --- infra_domain validation (domain name regex) ---

run "test_invalid_infra_domain_starts_with_dot" {
  command = plan

  variables {
    github_token = "test-token-placeholder"
    infra_domain = ".jclee.me"
  }

  expect_failures = [
    var.infra_domain,
  ]
}

run "test_invalid_infra_domain_uppercase" {
  command = plan

  variables {
    github_token = "test-token-placeholder"
    infra_domain = "JCLEE.ME"
  }

  expect_failures = [
    var.infra_domain,
  ]
}

# --- actions_allowed_actions validation (enum) ---

run "test_invalid_actions_allowed_invalid_value" {
  command = plan

  variables {
    github_token            = "test-token-placeholder"
    actions_allowed_actions = "custom"
  }

  expect_failures = [
    var.actions_allowed_actions,
  ]
}

# --- actions_enabled_repositories validation (enum) ---

run "test_invalid_actions_enabled_repos_invalid_value" {
  command = plan

  variables {
    github_token                 = "test-token-placeholder"
    actions_enabled_repositories = "custom"
  }

  expect_failures = [
    var.actions_enabled_repositories,
  ]
}

# --- organization_secret_visibility validation (enum) ---

run "test_invalid_secret_visibility_invalid_value" {
  command = plan

  variables {
    github_token                   = "test-token-placeholder"
    organization_secret_visibility = "public" # pragma: allowlist secret
  }

  expect_failures = [
    var.organization_secret_visibility,
  ]
}

# --- n8n_webhook URLs validation (empty or HTTP(S)) ---

run "test_invalid_n8n_webhook_glitchtip_no_protocol" {
  command = plan

  variables {
    github_token                    = "test-token-placeholder"
    n8n_webhook_glitchtip_error_url = "n8n.jclee.me/webhook/glitchtip"
  }

  expect_failures = [
    var.n8n_webhook_glitchtip_error_url,
  ]
}

run "test_invalid_n8n_webhook_grafana_ftp" {
  command = plan

  variables {
    github_token                  = "test-token-placeholder"
    n8n_webhook_grafana_alert_url = "ftp://n8n.jclee.me/webhook/grafana"
  }

  expect_failures = [
    var.n8n_webhook_grafana_alert_url,
  ]
}

run "test_invalid_n8n_webhook_issue_no_protocol" {
  command = plan

  variables {
    github_token                 = "test-token-placeholder"
    n8n_webhook_github_issue_url = "n8n.jclee.me/webhook/github-issue"
  }

  expect_failures = [
    var.n8n_webhook_github_issue_url,
  ]
}

run "test_invalid_n8n_webhook_pr_no_protocol" {
  command = plan

  variables {
    github_token              = "test-token-placeholder"
    n8n_webhook_github_pr_url = "n8n.jclee.me/webhook/github-pr"
  }

  expect_failures = [
    var.n8n_webhook_github_pr_url,
  ]
}
