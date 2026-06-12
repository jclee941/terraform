# =============================================================================
# 100-PVE VM CLOUD-INIT BASELINE TESTS
# =============================================================================

run "test_vm_cloud_init_baseline_refactor_contract" {
  command = plan

  assert {
    condition = alltrue([
      terraform.workspace != "",
      can(regex("vm_baseline_runcmd\\s*=\\s*\\[", file("../../../100-pve/terraform/cloud_init_baseline.tf"))),
      can(regex("systemctl enable qemu-guest-agent", file("../../../100-pve/terraform/cloud_init_baseline.tf"))),
      can(regex("systemctl start qemu-guest-agent", file("../../../100-pve/terraform/cloud_init_baseline.tf"))),
      can(regex("systemctl enable docker", file("../../../100-pve/terraform/cloud_init_baseline.tf"))),
      can(regex("systemctl start docker", file("../../../100-pve/terraform/cloud_init_baseline.tf"))),
      can(regex("PasswordAuthentication no", file("../../../100-pve/terraform/cloud_init_baseline.tf"))),
      can(regex("PermitRootLogin prohibit-password", file("../../../100-pve/terraform/cloud_init_baseline.tf"))),
      can(regex("systemctl enable fail2ban", file("../../../100-pve/terraform/cloud_init_baseline.tf"))),
      can(regex("systemctl start fail2ban", file("../../../100-pve/terraform/cloud_init_baseline.tf"))),
      can(regex("runcmd = concat\\(local\\.vm_baseline_runcmd", file("../../../100-pve/terraform/vm_configs.tf"))),
    ])
    error_message = "VM cloud-init baseline must retain qemu guest agent, Docker, SSH hardening, fail2ban, and VM runcmd concat usage."
  }
}
