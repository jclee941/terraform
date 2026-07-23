resource "null_resource" "lxc_cpu_limits" {
  for_each = local.lxc_cpu_limits

  triggers = {
    vmid      = tostring(each.value.vmid)
    cpu_limit = tostring(each.value.cpu_limit)
    cpu_units = tostring(each.value.cpu_units)
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
      "pct set ${self.triggers.vmid} --cpulimit ${self.triggers.cpu_limit} --cpuunits ${self.triggers.cpu_units}",
      "pct config ${self.triggers.vmid} | grep -E '^(cpulimit|cpuunits):'",
    ]
  }

  depends_on = [module.lxc]
}
