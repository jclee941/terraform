<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |
| <a name="requirement_github"></a> [github](#requirement\_github) | ~> 6.6 |
| <a name="requirement_onepassword"></a> [onepassword](#requirement\_onepassword) | ~> 3.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_github"></a> [github](#provider\_github) | 6.11.1 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_onepassword_secrets"></a> [onepassword\_secrets](#module\_onepassword\_secrets) | ../modules/shared/onepassword-secrets | n/a |

## Resources

| Name | Type |
|------|------|
| [github_actions_environment_secret.secrets](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_environment_secret) | resource |
| [github_actions_environment_variable.variables](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_environment_variable) | resource |
| [github_actions_organization_secret.organization](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_organization_secret) | resource |
| [github_actions_organization_variable.organization](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_organization_variable) | resource |
| [github_actions_secret.repositories](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_secret) | resource |
| [github_actions_variable.infra_endpoints](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_variable) | resource |
| [github_actions_variable.repositories](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_variable) | resource |
| [github_repository.repos](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository) | resource |
| [github_repository_dependabot_security_updates.repositories](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_dependabot_security_updates) | resource |
| [github_repository_deploy_key.keys](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_deploy_key) | resource |
| [github_repository_environment.environments](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_environment) | resource |
| [github_repository_file.codeowners](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_file) | resource |
| [github_repository_ruleset.branch](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_ruleset) | resource |
| [github_repository_ruleset.code_scanning](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_ruleset) | resource |
| [github_repository_ruleset.tags](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_ruleset) | resource |
| [github_repository_webhook.webhooks](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_webhook) | resource |
| [github_team.teams](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/team) | resource |
| [github_team_membership.memberships](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/team_membership) | resource |
| [github_team_repository.repository_access](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/team_repository) | resource |
| [terraform_data.validate_credentials](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_remote_state.infra](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_codeowners_management"></a> [enable\_codeowners\_management](#input\_enable\_codeowners\_management) | Enable Terraform-managed CODEOWNERS files. Disable when rulesets block direct commits. | `bool` | `false` | no |
| <a name="input_enable_infra_actions_variables"></a> [enable\_infra\_actions\_variables](#input\_enable\_infra\_actions\_variables) | Populate GitHub Actions variables with infrastructure endpoints from remote state. | `bool` | `false` | no |
| <a name="input_enable_repository_imports"></a> [enable\_repository\_imports](#input\_enable\_repository\_imports) | Enable import blocks for existing repositories. | `bool` | `false` | no |
| <a name="input_enable_repository_rulesets"></a> [enable\_repository\_rulesets](#input\_enable\_repository\_rulesets) | Enable repository rulesets management. | `bool` | `false` | no |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | GitHub organization or user | `string` | `"qws941"` | no |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | GitHub personal access token (optional if provided via 1Password) | `string` | `""` | no |
| <a name="input_infra_domain"></a> [infra\_domain](#input\_infra\_domain) | Infrastructure domain used to derive service URLs (e.g., mcphub.{domain}). | `string` | `"jclee.me"` | no |
| <a name="input_manage_as_organization"></a> [manage\_as\_organization](#input\_manage\_as\_organization) | Enable organization-only resources (teams, org secrets/variables). | `bool` | `false` | no |
| <a name="input_n8n_webhook_github_issue_url"></a> [n8n\_webhook\_github\_issue\_url](#input\_n8n\_webhook\_github\_issue\_url) | n8n webhook URL for GitHub issue automation. | `string` | `""` | no |
| <a name="input_n8n_webhook_github_pr_url"></a> [n8n\_webhook\_github\_pr\_url](#input\_n8n\_webhook\_github\_pr\_url) | n8n webhook URL for GitHub PR automation. | `string` | `""` | no |
| <a name="input_onepassword_vault_name"></a> [onepassword\_vault\_name](#input\_onepassword\_vault\_name) | 1Password vault name for secret lookups | `string` | `"homelab"` | no |
| <a name="input_organization_actions_secrets"></a> [organization\_actions\_secrets](#input\_organization\_actions\_secrets) | Organization Actions secrets as a map(secret\_name => plaintext\_value). | `map(string)` | `{}` | no |
| <a name="input_organization_actions_variables"></a> [organization\_actions\_variables](#input\_organization\_actions\_variables) | Organization Actions variables as a map(variable\_name => value). | `map(string)` | `{}` | no |
| <a name="input_organization_secret_visibility"></a> [organization\_secret\_visibility](#input\_organization\_secret\_visibility) | Visibility for organization-level secrets and variables: all, private, selected. | `string` | `"private"` | no |
| <a name="input_organization_variable_selected_repositories"></a> [organization\_variable\_selected\_repositories](#input\_organization\_variable\_selected\_repositories) | Selected repositories for each organization variable when visibility is selected. | `map(set(string))` | `{}` | no |
| <a name="input_repository_actions_secrets"></a> [repository\_actions\_secrets](#input\_repository\_actions\_secrets) | Repository Actions secrets as map(repo => map(secret\_name => plaintext\_value)). | `map(map(string))` | `{}` | no |
| <a name="input_repository_actions_variables"></a> [repository\_actions\_variables](#input\_repository\_actions\_variables) | Repository Actions variables as map(repo => map(variable\_name => value)). | `map(map(string))` | `{}` | no |
| <a name="input_repository_deploy_keys"></a> [repository\_deploy\_keys](#input\_repository\_deploy\_keys) | Deploy keys as map(repo => map(key\_title => { key, read\_only })). | <pre>map(map(object({<br/>    key       = string<br/>    read_only = bool<br/>  })))</pre> | `{}` | no |
| <a name="input_repository_environment_secrets"></a> [repository\_environment\_secrets](#input\_repository\_environment\_secrets) | Environment secrets as map(repo => map(environment => map(secret\_name => plaintext\_value))). | `map(map(map(string)))` | `{}` | no |
| <a name="input_repository_environment_variables"></a> [repository\_environment\_variables](#input\_repository\_environment\_variables) | Environment variables as map(repo => map(environment => map(variable\_name => value))). | `map(map(map(string)))` | `{}` | no |
| <a name="input_repository_environments"></a> [repository\_environments](#input\_repository\_environments) | Environment definitions as map(repo => map(environment => config)). | <pre>map(map(object({<br/>    wait_timer             = optional(number, 0)<br/>    can_admins_bypass      = optional(bool, true)<br/>    prevent_self_review    = optional(bool, true)<br/>    protected_branches     = optional(bool, true)<br/>    custom_branch_policies = optional(bool, false)<br/>    reviewer_user_ids      = optional(set(number), [])<br/>    reviewer_team_ids      = optional(set(number), [])<br/>  })))</pre> | <pre>{<br/>  "terraform": {<br/>    "production": {<br/>      "can_admins_bypass": true,<br/>      "custom_branch_policies": false,<br/>      "prevent_self_review": false,<br/>      "protected_branches": true,<br/>      "wait_timer": 0<br/>    }<br/>  }<br/>}</pre> | no |
| <a name="input_repository_webhooks"></a> [repository\_webhooks](#input\_repository\_webhooks) | Repository webhooks as map(repo => map(webhook\_name => webhook\_config)). | <pre>map(map(object({<br/>    url          = string<br/>    events       = set(string)<br/>    content_type = optional(string, "json")<br/>    active       = optional(bool, true)<br/>  })))</pre> | `{}` | no |
| <a name="input_ruleset_bypass_actors"></a> [ruleset\_bypass\_actors](#input\_ruleset\_bypass\_actors) | Bypass actors for repository rulesets (admin, integrations, etc.). | <pre>list(object({<br/>    actor_id    = number<br/>    actor_type  = string<br/>    bypass_mode = optional(string, "always")<br/>  }))</pre> | <pre>[<br/>  {<br/>    "actor_id": 5,<br/>    "actor_type": "RepositoryRole"<br/>  },<br/>  {<br/>    "actor_id": 1144995,<br/>    "actor_type": "Integration"<br/>  },<br/>  {<br/>    "actor_id": 1549082,<br/>    "actor_type": "Integration"<br/>  }<br/>]</pre> | no |
| <a name="input_security_code_scanning_tools"></a> [security\_code\_scanning\_tools](#input\_security\_code\_scanning\_tools) | Code scanning tools required by ruleset for each repository. | `map(set(string))` | <pre>{<br/>  "blacklist": [<br/>    "CodeQL"<br/>  ],<br/>  "hycu_fsds": [<br/>    "CodeQL"<br/>  ],<br/>  "propose": [<br/>    "CodeQL"<br/>  ],<br/>  "resume": [<br/>    "CodeQL"<br/>  ],<br/>  "splunk": [<br/>    "CodeQL"<br/>  ],<br/>  "terraform": [<br/>    "CodeQL"<br/>  ],<br/>  "tmux": [<br/>    "CodeQL"<br/>  ],<br/>  "youtube": [<br/>    "CodeQL"<br/>  ]<br/>}</pre> | no |
| <a name="input_security_dependabot_enabled"></a> [security\_dependabot\_enabled](#input\_security\_dependabot\_enabled) | Enable Dependabot security updates by repository. | `map(bool)` | <pre>{<br/>  "blacklist": true,<br/>  "hycu_fsds": true,<br/>  "propose": true,<br/>  "resume": true,<br/>  "splunk": true,<br/>  "terraform": true,<br/>  "tmux": true,<br/>  "youtube": true<br/>}</pre> | no |
| <a name="input_team_memberships"></a> [team\_memberships](#input\_team\_memberships) | Team memberships as map(team\_key => map(username => role)). | `map(map(string))` | `{}` | no |
| <a name="input_team_repository_access"></a> [team\_repository\_access](#input\_team\_repository\_access) | Team repo access as map(team\_key => map(repo\_name => permission)). | `map(map(string))` | `{}` | no |
| <a name="input_teams"></a> [teams](#input\_teams) | Organization teams keyed by team slug key. | <pre>map(object({<br/>    name                 = string<br/>    description          = optional(string, "")<br/>    privacy              = optional(string, "closed")<br/>    notification_setting = optional(string, "notifications_enabled")<br/>  }))</pre> | <pre>{<br/>  "platform": {<br/>    "description": "Platform engineering team",<br/>    "name": "platform",<br/>    "privacy": "closed"<br/>  }<br/>}</pre> | no |
| <a name="input_webhook_insecure_ssl"></a> [webhook\_insecure\_ssl](#input\_webhook\_insecure\_ssl) | Whether to allow insecure SSL for webhook delivery. | `bool` | `false` | no |
| <a name="input_webhook_secret"></a> [webhook\_secret](#input\_webhook\_secret) | Shared secret used by repository webhooks. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_infra_integration"></a> [infra\_integration](#output\_infra\_integration) | Infrastructure data consumed from 100-pve remote state. |
| <a name="output_n8n_webhook_urls"></a> [n8n\_webhook\_urls](#output\_n8n\_webhook\_urls) | Effective n8n webhook URLs (derived from infra domain or overridden by variables). |
| <a name="output_repository_clone_urls"></a> [repository\_clone\_urls](#output\_repository\_clone\_urls) | Managed repository clone URLs (HTTPS and SSH). |
| <a name="output_repository_html_urls"></a> [repository\_html\_urls](#output\_repository\_html\_urls) | Managed repository HTML URLs by repository name. |
| <a name="output_repository_webhook_ids"></a> [repository\_webhook\_ids](#output\_repository\_webhook\_ids) | Repository webhook IDs keyed by repo:webhook\_name. |
| <a name="output_team_ids"></a> [team\_ids](#output\_team\_ids) | Team IDs keyed by team key. |
<!-- END_TF_DOCS -->
