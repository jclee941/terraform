run "test_single_vm_cloud_init" {
  command = apply

  module {
    source = "../../../modules/proxmox/vm-config"
  }

  variables {
    vms = {
      sandbox = {
        vmid       = 220
        hostname   = "sandbox"
        ip_address = "192.168.50.220"
        cloud_init = {
          packages = ["qemu-guest-agent", "curl", "vim", "git"]
          runcmd = [
            "systemctl enable qemu-guest-agent",
            "systemctl start qemu-guest-agent"
          ]
        }
        deploy = false
      }
    }

    deploy_vm_configs    = false
    enable_health_checks = false
  }

  assert {
    condition = (
      length(keys(output.vm_configs)) == 1 &&
      contains(keys(output.vm_configs), "sandbox") &&
      try(output.vm_configs.sandbox.vmid, 0) == 220 &&
      try(output.vm_configs.sandbox.hostname, "") == "sandbox" &&
      try(output.vm_configs.sandbox.ip_address, "") == "192.168.50.220" &&
      endswith(try(output.vm_configs.sandbox.cloud_init, ""), "/configs/vm-220-sandbox/cloud-init.yaml") &&
      length(try(output.vm_configs.sandbox.systemd_services, [])) == 0 &&
      contains(keys(output.cloud_init_paths), "sandbox") &&
      endswith(try(output.cloud_init_paths.sandbox, ""), "/configs/vm-220-sandbox/cloud-init.yaml")
    )
    error_message = "single VM should generate vm_configs and cloud_init_paths entries for sandbox"
  }
}

run "test_vm_with_systemd_services" {
  command = apply

  module {
    source = "../../../modules/proxmox/vm-config"
  }

  variables {
    vms = {
      oc = {
        vmid       = 200
        hostname   = "oc"
        ip_address = "192.168.50.200"
        cloud_init = {
          packages = ["qemu-guest-agent", "curl", "git"]
        }
        systemd_services = {
          opencode-agent = {
            description = "OpenCode worker"
            exec_start  = "/usr/local/bin/opencode-agent"
            working_dir = "/opt/opencode"
            user        = "jclee"
          }
          nvidia-persistenced = {
            description = "NVIDIA persistence daemon"
            exec_start  = "/usr/bin/nvidia-persistenced --verbose"
          }
        }
        deploy = false
      }
    }

    deploy_vm_configs = false
  }

  assert {
    condition = (
      try(output.vm_configs.oc.vmid, 0) == 200 &&
      try(output.vm_configs.oc.hostname, "") == "oc" &&
      try(output.vm_configs.oc.ip_address, "") == "192.168.50.200" &&
      endswith(try(output.vm_configs.oc.cloud_init, ""), "/configs/vm-200-oc/cloud-init.yaml") &&
      length(try(output.vm_configs.oc.systemd_services, [])) == 2 &&
      toset([for svc in output.vm_configs.oc.systemd_services : svc.name]) == toset(["opencode-agent", "nvidia-persistenced"]) &&
      length([
        for svc in output.vm_configs.oc.systemd_services : svc
        if svc.name == "opencode-agent" && endswith(svc.path, "/configs/vm-200-oc/opencode-agent.service")
      ]) == 1 &&
      length([
        for svc in output.vm_configs.oc.systemd_services : svc
        if svc.name == "nvidia-persistenced" && endswith(svc.path, "/configs/vm-200-oc/nvidia-persistenced.service")
      ]) == 1 &&
      endswith(try(output.cloud_init_paths.oc, ""), "/configs/vm-200-oc/cloud-init.yaml")
    )
    error_message = "VM with systemd services should expose both service names and generated paths"
  }
}

run "test_vm_without_cloud_init" {
  command = apply

  module {
    source = "../../../modules/proxmox/vm-config"
  }

  variables {
    vms = {
      sandbox = {
        vmid       = 220
        hostname   = "sandbox"
        ip_address = "192.168.50.220"
        cloud_init = null
        deploy     = false
      }
    }

    deploy_vm_configs = false
  }

  assert {
    condition = (
      try(output.vm_configs.sandbox.vmid, 0) == 220 &&
      try(output.vm_configs.sandbox.hostname, "") == "sandbox" &&
      try(output.vm_configs.sandbox.ip_address, "") == "192.168.50.220" &&
      try(output.vm_configs.sandbox.cloud_init, null) != null &&
      endswith(try(output.vm_configs.sandbox.cloud_init, ""), "/configs/vm-220-sandbox/cloud-init.yaml") &&
      length(try(output.vm_configs.sandbox.systemd_services, [])) == 0 &&
      endswith(try(output.cloud_init_paths.sandbox, ""), "/configs/vm-220-sandbox/cloud-init.yaml")
    )
    error_message = "VM with null cloud_init should still produce generated cloud-init output path"
  }
}

run "test_multiple_vms" {
  command = apply

  module {
    source = "../../../modules/proxmox/vm-config"
  }

  variables {
    vms = {
      oc = {
        vmid       = 200
        hostname   = "oc"
        ip_address = "192.168.50.200"
        deploy     = false
      }
      sandbox = {
        vmid       = 220
        hostname   = "sandbox"
        ip_address = "192.168.50.220"
        deploy     = false
      }
    }

    deploy_vm_configs = false
  }

  assert {
    condition = (
      length(keys(output.vm_configs)) == 2 &&
      contains(keys(output.vm_configs), "oc") &&
      contains(keys(output.vm_configs), "sandbox") &&
      try(output.vm_configs.oc.vmid, 0) == 200 &&
      try(output.vm_configs.oc.hostname, "") == "oc" &&
      try(output.vm_configs.oc.ip_address, "") == "192.168.50.200" &&
      try(output.vm_configs.sandbox.vmid, 0) == 220 &&
      try(output.vm_configs.sandbox.hostname, "") == "sandbox" &&
      try(output.vm_configs.sandbox.ip_address, "") == "192.168.50.220"
    )
    error_message = "multiple VMs should both appear in vm_configs with correct vm metadata"
  }
}

run "test_cloud_init_paths_output" {
  command = apply

  module {
    source = "../../../modules/proxmox/vm-config"
  }

  variables {
    vms = {
      oc = {
        vmid       = 200
        hostname   = "oc"
        ip_address = "192.168.50.200"
        deploy     = false
      }
      sandbox = {
        vmid       = 220
        hostname   = "sandbox"
        ip_address = "192.168.50.220"
        deploy     = false
      }
    }

    deploy_vm_configs = false
  }

  assert {
    condition = (
      length(keys(output.cloud_init_paths)) == 2 &&
      contains(keys(output.cloud_init_paths), "oc") &&
      contains(keys(output.cloud_init_paths), "sandbox") &&
      endswith(try(output.cloud_init_paths.oc, ""), "/configs/vm-200-oc/cloud-init.yaml") &&
      endswith(try(output.cloud_init_paths.sandbox, ""), "/configs/vm-220-sandbox/cloud-init.yaml") &&
      endswith(try(output.vm_configs.oc.cloud_init, ""), "/configs/vm-200-oc/cloud-init.yaml") &&
      endswith(try(output.vm_configs.sandbox.cloud_init, ""), "/configs/vm-220-sandbox/cloud-init.yaml")
    )
    error_message = "cloud_init_paths output should map each VM to its generated cloud-init file"
  }
}
