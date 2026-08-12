locals {
  proxmox_monitor_sources = {
    client   = "client.go"
    config   = "config.go"
    evaluate = "evaluate.go"
    format   = "format.go"
    main     = "main.go"
    model    = "model.go"
    state    = "state.go"
  }
}

resource "synology_container_project" "proxmox_monitor" {
  for_each = var.enable_proxmox_monitor ? { this = true } : {}

  name = "proxmox-monitor"
  run  = true

  services = {
    monitor = {
      image          = var.proxmox_monitor_image
      container_name = "proxmox-monitor"
      init           = true
      restart        = "unless-stopped"
      mem_limit      = "128m"
      cap_drop       = ["ALL"]
      security_opt   = ["no-new-privileges:true"]
      command = [
        "sh",
        "-c",
        "go build -trimpath -ldflags='-s -w' -o /tmp/proxmox-monitor /app/*.go && exec /tmp/proxmox-monitor",
      ]
      environment = {
        PROXMOX_ENDPOINT_FILE     = "/run/secrets/proxmox_endpoint"
        PROXMOX_API_TOKEN_FILE    = "/run/secrets/proxmox_api_token"
        PROXMOX_INSECURE          = "true"
        TELEGRAM_BOT_TOKEN_FILE   = "/run/secrets/telegram_bot_token"
        TELEGRAM_CHAT_ID_FILE     = "/run/secrets/telegram_chat_id"
        MONITOR_INTERVAL          = var.proxmox_monitor_interval
        MONITOR_FAILURE_THRESHOLD = tostring(var.proxmox_monitor_failure_threshold)
        MONITOR_CPU_PERCENT       = tostring(var.proxmox_monitor_cpu_percent)
        MONITOR_MEMORY_PERCENT    = tostring(var.proxmox_monitor_memory_percent)
        MONITOR_DISK_PERCENT      = tostring(var.proxmox_monitor_disk_percent)
      }
      configs = [for key, filename in local.proxmox_monitor_sources : {
        source = "monitor_${key}"
        target = "/app/${filename}"
        mode   = "0444"
      }]
      secrets = [for name in ["proxmox_endpoint", "proxmox_api_token", "telegram_bot_token", "telegram_chat_id"] : {
        source = name
        target = name
        mode   = "0400"
      }]
      volumes = [{
        type   = "volume"
        source = "monitor-state"
        target = "/data"
      }]
      healthcheck = {
        test     = ["CMD-SHELL", "test -f /data/state.json && test $(( $(date +%s) - $(stat -c %Y /data/state.json) )) -lt 300"]
        interval = "60s"
        timeout  = "5s"
        retries  = 3
      }
      logging = {
        driver = "json-file"
        options = {
          max-size = "10m"
          max-file = "3"
        }
      }
    }
  }

  configs = {
    for key, filename in local.proxmox_monitor_sources : "monitor_${key}" => {
      name    = "proxmox-monitor-${key}"
      content = file("${path.module}/monitor/${filename}")
    }
  }

  secrets = {
    proxmox_endpoint = {
      name    = "proxmox-monitor-proxmox-endpoint"
      content = local.proxmox_monitor_endpoint
    }
    proxmox_api_token = {
      name    = "proxmox-monitor-proxmox-api-token"
      content = local.proxmox_monitor_api_token
    }
    telegram_bot_token = {
      name    = "proxmox-monitor-telegram-bot-token"
      content = local.proxmox_monitor_telegram_token
    }
    telegram_chat_id = {
      name    = "proxmox-monitor-telegram-chat-id"
      content = local.proxmox_monitor_chat_id
    }
  }

  volumes = {
    monitor-state = {
      name = "proxmox-monitor-state"
    }
  }

  depends_on = [synology_core_package.container_manager]
}
