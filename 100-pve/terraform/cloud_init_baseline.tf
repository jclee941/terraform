# =============================================================================
# CLOUD-INIT BASELINES
# =============================================================================

locals {
  vm_baseline_runcmd = [
    "systemctl enable qemu-guest-agent || true",
    "systemctl start qemu-guest-agent || true",
    "systemctl enable docker",
    "systemctl start docker",
    "# SSH hardening",
    "sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config",
    "sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config",
    "systemctl restart sshd",
    "# fail2ban SSH jail",
    "printf '[sshd]\\nenabled = true\\nport = ssh\\nfilter = sshd\\nmaxretry = 5\\nbantime = 3600\\n' > /etc/fail2ban/jail.d/sshd.conf",
    "systemctl enable fail2ban",
    "systemctl start fail2ban",
  ]

  vm_filebeat_write_file_defaults = {
    path        = "/etc/filebeat/filebeat.yml"
    permissions = "0644"
    owner       = "root:root"
  }
}
