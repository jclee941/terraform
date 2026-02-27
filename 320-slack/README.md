# 320-slack

Slack workspace management via Terraform (`pablovarela/slack` provider).

## Overview

Manages Slack channels, usergroups, and membership as code.

## Auth

Bot token sourced from 1Password vault `homelab`. Override with `TF_VAR_slack_bot_token`.

Required bot scopes: `channels:read`, `channels:manage`, `channels:join`, `groups:read`, `groups:write`, `usergroups:read`, `usergroups:write`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7, < 2.0 |
| <a name="requirement_onepassword"></a> [onepassword](#requirement\_onepassword) | ~> 3.2 |
| <a name="requirement_slack"></a> [slack](#requirement\_slack) | ~> 1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_slack"></a> [slack](#provider\_slack) | 1.2.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_onepassword_secrets"></a> [onepassword\_secrets](#module\_onepassword\_secrets) | ../modules/shared/onepassword-secrets | n/a |

## Resources

| Name | Type |
|------|------|
| [slack_conversation.channels](https://registry.terraform.io/providers/pablovarela/slack/latest/docs/resources/conversation) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_onepassword_vault_name"></a> [onepassword\_vault\_name](#input\_onepassword\_vault\_name) | 1Password vault name | `string` | `"homelab"` | no |
| <a name="input_slack_bot_token"></a> [slack\_bot\_token](#input\_slack\_bot\_token) | Slack bot token override (xoxb-*). Falls back to 1Password. | `string` | `""` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
