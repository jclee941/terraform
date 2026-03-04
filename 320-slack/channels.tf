# Channel definitions — adopt all existing channels into Terraform state.
#
# Categories:
#   default    — Slack workspace defaults (general, random). Cannot be archived.
#   notify     — Unified notification channels for external service integrations.
#   archived   — All legacy channels, frozen via is_archived.

locals {
  channels = {
    # ── Default channels ──────────────────────────────────────────────
    "general" = {
      name              = "일반"
      purpose           = "이것은 언제나 모두를 포함하게 될 단 하나의 채널로 공지를 올리고 팀 전체의 대화를 나누기에 적합한 공간입니다."
      action_on_destroy = "none"
    }
    "random" = {
      name              = "랜덤"
      purpose           = "이 채널은 어떤 것이든 나눌 수 있습니다. 팀 내 농담, 즉흥적인 아이디어, 재밌는 GIF를 위한 공간입니다."
      action_on_destroy = "none"
    }

    # ── Notification channels ─────────────────────────────────────────
    "github" = {
      name    = "github"
      topic   = "GitHub activity — PRs, issues, CI/CD, releases"
      purpose = "Unified GitHub webhook notifications for all qws941 repositories."
    }
    "alerts" = {
      name    = "alerts"
      topic   = "Infrastructure alerts — Grafana, GlitchTip, uptime"
      purpose = "Unified infrastructure and monitoring alerts."
    }

    # ── Archived — service channels ───────────────────────────────────
    "mcp" = {
      name        = "mcp"
      is_archived = true
    }
    "opencode" = {
      name        = "opencode"
      topic       = "opencode session events"
      is_archived = true
    }

    # ── Archived — tmux channels ──────────────────────────────────────
    "tmux" = {
      name        = "tmux"
      topic       = "tmux session lifecycle events"
      is_archived = true
    }
    "tmux-blacklist" = {
      name        = "tmux-blacklist"
      topic       = "tmux session: blacklist"
      is_archived = true
    }
    "tmux-oh-my-opencode" = {
      name        = "tmux-oh-my-opencode"
      topic       = "tmux session: oh-my-opencode"
      is_archived = true
    }
    "tmux-prize" = {
      name        = "tmux-prize"
      topic       = "tmux session: prize"
      is_archived = true
    }
    "tmux-propose" = {
      name        = "tmux-propose"
      topic       = "tmux session: propose"
      is_archived = true
    }
    "tmux-resume" = {
      name        = "tmux-resume"
      topic       = "tmux session: resume"
      is_archived = true
    }
    "tmux-safetywallet" = {
      name        = "tmux-safetywallet"
      topic       = "tmux session: safetywallet"
      is_archived = true
    }
    "tmux-terraform" = {
      name        = "tmux-terraform"
      topic       = "tmux session: terraform"
      is_archived = true
    }

    # ── Archived — legacy numbered channels ───────────────────────────
    "09-splunk-dev" = {
      name        = "09_splunk_dev"
      is_archived = true
    }
    "10-hycu" = {
      name        = "10_hycu"
      is_archived = true
    }

    # ── Archived — ephemeral tmux sessions ────────────────────────────
    "tmux-splunk" = {
      name        = "tmux-splunk"
      topic       = "tmux session: splunk"
      is_archived = true
    }
    "tmux-op-signin" = {
      name        = "tmux-op-signin"
      topic       = "tmux session: op-signin"
      is_archived = true
    }
    "tmux-wrangler-login" = {
      name        = "tmux-wrangler-login"
      topic       = "tmux session: wrangler-login"
      is_archived = true
    }
    "tmux-tf-plan" = {
      name        = "tmux-tf-plan"
      topic       = "tmux session: tf-plan"
      is_archived = true
    }
    "tmux-_github" = {
      name        = "tmux-_github"
      topic       = "tmux session: _github"
      is_archived = true
    }
    "tmux-review" = {
      name        = "tmux-review"
      topic       = "tmux session: review"
      is_archived = true
    }
    "tmux-cr" = {
      name        = "tmux-cr"
      topic       = "tmux session: cr"
      is_archived = true
    }
    "tmux-vm109" = {
      name        = "tmux-vm109"
      topic       = "tmux session: vm109"
      is_archived = true
    }
  }
}

resource "slack_conversation" "channels" {
  for_each = local._slack_enabled ? local.channels : {}

  name                   = each.value.name
  topic                  = lookup(each.value, "topic", null)
  purpose                = lookup(each.value, "purpose", null)
  is_private             = false
  is_archived            = lookup(each.value, "is_archived", false)
  adopt_existing_channel = true
  action_on_destroy      = lookup(each.value, "action_on_destroy", "archive")
}
