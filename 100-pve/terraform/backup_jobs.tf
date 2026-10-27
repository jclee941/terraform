# =============================================================================
# BACKUP JOBS — IaC-managed vzdump schedules through the Proxmox API
# =============================================================================
# Note: bpg/proxmox provider does NOT expose a cluster_backup_job resource as of
# v0.98.1. We converge the owned jobs through pvesh over SSH + null_resource.
#
# Storage target: PBS (datastore "backups" on 192.168.50.250).
# Retention: PBS prune-job handles long-term retention; vzdump only emits new
# snapshots — actual pruning is centralised in PBS.

locals {
  backup_jobs = {
    lxc-daily = {
      comment       = "Daily LXC backups - critical infra (cliproxy)"
      schedule      = "02:00"
      vmid          = "114"
      storage       = "pbs-backup"
      bwlimit       = 81920
      prune_backups = "keep-last=7,keep-weekly=4,keep-monthly=3"
    }
    lxc-weekly = {
      comment       = "Weekly LXC backups - heavy workloads (elk)"
      schedule      = "sun 03:00"
      vmid          = "105"
      storage       = "pbs-backup"
      bwlimit       = 81920
      prune_backups = "keep-last=4,keep-weekly=2,keep-monthly=2"
    }
    vm-daily = {
      comment       = "Daily VM backups (jclee-dev, jclee-prd)"
      schedule      = "04:00"
      vmid          = "200,220"
      storage       = "pbs-backup"
      bwlimit       = 81920
      prune_backups = "keep-last=7,keep-weekly=4,keep-monthly=3"
    }
  }

  backup_job_commands = {
    for job_id, job in local.backup_jobs : job_id => <<-EOT
      set -eu
      if pvesh get "/cluster/backup/${job_id}" --quiet >/dev/null 2>&1; then
        pvesh set "/cluster/backup/${job_id}" \
          --schedule '${replace(job.schedule, "'", "'\"'\"'")}' \
          --storage '${replace(job.storage, "'", "'\"'\"'")}' \
          --vmid '${replace(job.vmid, "'", "'\"'\"'")}' \
          --bwlimit '${job.bwlimit}' \
          --mode snapshot \
          --compress zstd \
          --enabled 1 \
          --mailnotification failure \
          --mailto 'admin@jclee.me' \
          --prune-backups '${replace(job.prune_backups, "'", "'\"'\"'")}' \
          --comment '${replace(job.comment, "'", "'\"'\"'")}'
      else
        pvesh create /cluster/backup \
          --id '${replace(job_id, "'", "'\"'\"'")}' \
          --schedule '${replace(job.schedule, "'", "'\"'\"'")}' \
          --storage '${replace(job.storage, "'", "'\"'\"'")}' \
          --vmid '${replace(job.vmid, "'", "'\"'\"'")}' \
          --bwlimit '${job.bwlimit}' \
          --mode snapshot \
          --compress zstd \
          --enabled 1 \
          --mailnotification failure \
          --mailto 'admin@jclee.me' \
          --prune-backups '${replace(job.prune_backups, "'", "'\"'\"'")}' \
          --comment '${replace(job.comment, "'", "'\"'\"'")}'
      fi
      pvesh get "/cluster/backup/${job_id}" --output-format json >/dev/null
    EOT
  }
}

resource "null_resource" "backup_jobs" {
  for_each = var.enable_pbs && var.deploy_lxc_configs ? local.backup_jobs : {}

  triggers = merge(each.value, {
    command_contract = sha256(local.backup_job_commands[each.key])
  })

  connection {
    type        = "ssh"
    host        = local.proxmox_host
    user        = "root"
    private_key = lookup(module.onepassword_secrets.secrets, "proxmox_ssh_private_key", "")
  }

  provisioner "remote-exec" {
    inline = [local.backup_job_commands[each.key]]
  }
}

# =============================================================================
# PBS prune-job and verify-job (datastore-side retention + integrity checks)
# =============================================================================
# These are managed via PBS HTTP API. As bpg/proxmox provider doesn't cover PBS
# config endpoints, we use null_resource calling curl.

resource "null_resource" "pbs_gc_schedule" {
  count = var.enable_pbs ? 1 : 0

  triggers = {
    schedule = "sun 06:00"
  }

  provisioner "local-exec" {
    command = <<-EOT
      PBS_CURL_AUTH='root@pam:${module.onepassword_secrets.secrets["pbs_password"]}'
      curl -sk -X PUT \
        --user "$${PBS_CURL_AUTH}" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode 'gc-schedule=${self.triggers.schedule}' \
        'https://${module.onepassword_secrets.metadata["pbs_server"]}:8007/api2/json/config/datastore/backups' \
        | grep -q '"data":null' && echo 'PBS GC schedule set'
    EOT
  }
}

resource "null_resource" "pbs_prune_job" {
  count = var.enable_pbs ? 1 : 0

  triggers = {
    config = "daily:7d/4w/3m"
  }

  provisioner "local-exec" {
    command = <<-EOT
      PBS_CURL_AUTH='root@pam:${module.onepassword_secrets.secrets["pbs_password"]}'
      curl -sk -X POST \
        --user "$${PBS_CURL_AUTH}" \
        -H 'Content-Type: application/json' \
        --data '{"id":"prune-backups-daily","store":"backups","schedule":"daily","keep-last":7,"keep-weekly":4,"keep-monthly":3,"comment":"Daily prune: 7d/4w/3m"}' \
        'https://${module.onepassword_secrets.metadata["pbs_server"]}:8007/api2/json/config/prune' \
        || echo 'prune-job already exists or updated'
    EOT
  }
}

resource "null_resource" "pbs_verify_job" {
  count = var.enable_pbs ? 1 : 0

  triggers = {
    config = "monthly:30d-outdated"
  }

  provisioner "local-exec" {
    command = <<-EOT
      PBS_CURL_AUTH='root@pam:${module.onepassword_secrets.secrets["pbs_password"]}'
      curl -sk -X POST \
        --user "$${PBS_CURL_AUTH}" \
        -H 'Content-Type: application/json' \
        --data '{"id":"verify-backups-monthly","store":"backups","schedule":"monthly","ignore-verified":true,"outdated-after":30,"comment":"Monthly verify: re-check chunks >30d"}' \
        'https://${module.onepassword_secrets.metadata["pbs_server"]}:8007/api2/json/config/verify' \
        || echo 'verify-job already exists or updated'
    EOT
  }
}

output "backup_jobs_summary" {
  description = "Summary of vzdump + PBS automation status"
  value = {
    vzdump_jobs         = ["lxc-daily", "lxc-weekly", "vm-daily"]
    pbs_gc_schedule     = "sun 06:00"
    pbs_prune_schedule  = "daily (keep 7d/4w/3m)"
    pbs_verify_schedule = "monthly"
    pbs_storage_id      = "pbs-backup"
  }
}
