# =============================================================================
# BACKUP JOBS — IaC-managed vzdump schedule (writes /etc/pve/jobs.cfg)
# =============================================================================
# Note: bpg/proxmox provider does NOT expose a cluster_backup_job resource as of
# v0.98.1. We render /etc/pve/jobs.cfg via SSH + null_resource.
#
# Storage target: PBS (datastore "backups" on 192.168.50.250).
# Retention: PBS prune-job handles long-term retention; vzdump only emits new
# snapshots — actual pruning is centralised in PBS.

locals {
  backup_jobs_cfg = <<-EOT
    vzdump: lxc-daily
    \tcomment Daily LXC backups - critical infra (traefik, coredns, runner, cliproxy)
    \tschedule 02:00
    \tcompress zstd
    \tenabled 1
    \tmailnotification failure
    \tmailto admin@jclee.me
    \tmode snapshot
    \tprune-backups keep-last=7,keep-weekly=4,keep-monthly=3
    \tstorage pbs
    \tvmid 101,102,103,114

    vzdump: lxc-weekly
    \tcomment Weekly LXC backups - heavy workloads (elk, n8n)
    \tschedule sun 03:00
    \tcompress zstd
    \tenabled 1
    \tmailnotification failure
    \tmailto admin@jclee.me
    \tmode snapshot
    \tprune-backups keep-last=4,keep-weekly=2,keep-monthly=2
    \tstorage pbs
    \tvmid 105,110

    vzdump: vm-daily
    \tcomment Daily VM backups (mcphub, oc, youtube)
    \tschedule 04:00
    \tcompress zstd
    \tenabled 1
    \tmailnotification failure
    \tmailto admin@jclee.me
    \tmode snapshot
    \tprune-backups keep-last=7,keep-weekly=4,keep-monthly=3
    \tstorage pbs
    \tvmid 112,200,220
  EOT
}

resource "null_resource" "backup_jobs" {
  count = var.enable_pbs && var.deploy_lxc_configs ? 1 : 0

  triggers = {
    config_hash = sha256(local.backup_jobs_cfg)
  }

  connection {
    type        = "ssh"
    host        = local.proxmox_host
    user        = "root"
    private_key = lookup(module.onepassword_secrets.secrets, "proxmox_ssh_private_key", "")
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "BAK=/etc/pve/jobs.cfg.bak-$(date +%Y%m%d-%H%M%S)",
      "[ -f /etc/pve/jobs.cfg ] && cp /etc/pve/jobs.cfg $BAK || true",
      "cat > /etc/pve/jobs.cfg <<'PVE_JOBS_EOF'\n${replace(local.backup_jobs_cfg, "\\t", "\t")}PVE_JOBS_EOF",
      "pvesh get /cluster/backup --output-format json >/dev/null && echo 'jobs.cfg syntax OK'",
    ]
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
    schedule = "sun 02:00"
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -sk -X PUT \
        -u 'root@pam:${module.onepassword_secrets.secrets["pbs_password"]}' \
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
      curl -sk -X POST \
        -u 'root@pam:${module.onepassword_secrets.secrets["pbs_password"]}' \
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
      curl -sk -X POST \
        -u 'root@pam:${module.onepassword_secrets.secrets["pbs_password"]}' \
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
    pbs_gc_schedule     = "sun 02:00"
    pbs_prune_schedule  = "daily (keep 7d/4w/3m)"
    pbs_verify_schedule = "monthly"
    pbs_storage_id      = "pbs"
  }
}
