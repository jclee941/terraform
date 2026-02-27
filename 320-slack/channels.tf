# Channel definitions — adopt all existing channels into Terraform state.
#
# Categories:
#   default    — Slack workspace defaults (general, random). Cannot be archived.
#   legacy     — Numbered service channels from early workspace setup.
#   service    — Current service/project channels.
#   tmux       — tmux-bridge bot channels (auto-created per session).

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

    # ── Legacy numbered channels ──────────────────────────────────────
    "01-blacklist" = {
      name = "01_blacklist"
    }
    "03-fortinet" = {
      name = "03_fortinet"
    }
    "04-grafana" = {
      name = "04_grafana"
    }
    "05-infra" = {
      name = "05_infra"
    }
    "06-n8n" = {
      name = "06_n8n"
    }
    "07-nginx" = {
      name = "07_nginx"
    }
    "08-safework" = {
      name = "08_safework"
    }
    "10-hycu" = {
      name = "10_hycu"
    }

    # ── Service channels ──────────────────────────────────────────────
    "mcp" = {
      name = "mcp"
    }
    "opencode" = {
      name  = "opencode"
      topic = "opencode session events"
    }
    # ── tmux-bridge channels ──────────────────────────────────────────
    "tmux" = {
      name  = "tmux"
      topic = "tmux session lifecycle events"
    }
    "tmux-blacklist" = {
      name  = "tmux-blacklist"
      topic = "tmux session: blacklist"
    }
    "tmux-oh-my-opencode" = {
      name  = "tmux-oh-my-opencode"
      topic = "tmux session: oh-my-opencode"
    }
    "tmux-prize" = {
      name  = "tmux-prize"
      topic = "tmux session: prize"
    }
    "tmux-propose" = {
      name  = "tmux-propose"
      topic = "tmux session: propose"
    }
    "tmux-resume" = {
      name  = "tmux-resume"
      topic = "tmux session: resume"
    }
    "tmux-safetywallet" = {
      name  = "tmux-safetywallet"
      topic = "tmux session: safetywallet"
    }
    "tmux-terraform" = {
      name  = "tmux-terraform"
      topic = "tmux session: terraform"
    }
    "tmux-tf-plan" = {
      name  = "tmux-tf-plan"
      topic = "tmux session: tf-plan"
    }
    "tmux-vm220" = {
      name  = "tmux-vm220"
      topic = "tmux session: vm220"
    }
    "tmux-youtube" = {
      name  = "tmux-youtube"
      topic = "tmux session: youtube"
    }
  }
}

resource "slack_conversation" "channels" {
  for_each = local.channels

  name                   = each.value.name
  topic                  = lookup(each.value, "topic", null)
  purpose                = lookup(each.value, "purpose", null)
  is_private             = false
  adopt_existing_channel = true
  action_on_destroy      = lookup(each.value, "action_on_destroy", "archive")
}
