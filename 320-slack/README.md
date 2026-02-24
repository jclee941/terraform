# 320-slack

Slack workspace management via Terraform (`pablovarela/slack` provider).

## Overview

Manages Slack channels, usergroups, and membership as code.

## Auth

Bot token sourced from 1Password vault `homelab`. Override with `TF_VAR_slack_bot_token`.

Required bot scopes: `channels:read`, `channels:manage`, `channels:join`, `groups:read`, `groups:write`, `usergroups:read`, `usergroups:write`.
