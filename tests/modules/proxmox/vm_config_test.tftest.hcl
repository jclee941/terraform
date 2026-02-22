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
      runner = {
        vmid       = 101
        hostname   = "runner"
        ip_address = "192.168.50.101"
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
      try(output.vm_configs.runner.vmid, 0) == 101 &&
      try(output.vm_configs.runner.hostname, "") == "runner" &&
      try(output.vm_configs.runner.ip_address, "") == "192.168.50.101" &&
      endswith(try(output.vm_configs.runner.cloud_init, ""), "/configs/vm-101-runner/cloud-init.yaml") &&
      length(try(output.vm_configs.runner.systemd_services, [])) == 2 &&
      toset([for svc in output.vm_configs.runner.systemd_services : svc.name]) == toset(["opencode-agent", "nvidia-persistenced"]) &&
      length([
        for svc in output.vm_configs.runner.systemd_services : svc
        if svc.name == "opencode-agent" && endswith(svc.path, "/configs/vm-101-runner/opencode-agent.service")
      ]) == 1 &&
      length([
        for svc in output.vm_configs.runner.systemd_services : svc
        if svc.name == "nvidia-persistenced" && endswith(svc.path, "/configs/vm-101-runner/nvidia-persistenced.service")
      ]) == 1 &&
      endswith(try(output.cloud_init_paths.runner, ""), "/configs/vm-101-runner/cloud-init.yaml")
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
      runner = {
        vmid       = 101
        hostname   = "runner"
        ip_address = "192.168.50.101"
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
      contains(keys(output.vm_configs), "runner") &&
      contains(keys(output.vm_configs), "sandbox") &&
      try(output.vm_configs.runner.vmid, 0) == 101 &&
      try(output.vm_configs.runner.hostname, "") == "runner" &&
      try(output.vm_configs.runner.ip_address, "") == "192.168.50.101" &&
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
      runner = {
        vmid       = 101
        hostname   = "runner"
        ip_address = "192.168.50.101"
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
      contains(keys(output.cloud_init_paths), "runner") &&
      contains(keys(output.cloud_init_paths), "sandbox") &&
      endswith(try(output.cloud_init_paths.runner, ""), "/configs/vm-101-runner/cloud-init.yaml") &&
      endswith(try(output.cloud_init_paths.sandbox, ""), "/configs/vm-220-sandbox/cloud-init.yaml") &&
      endswith(try(output.vm_configs.runner.cloud_init, ""), "/configs/vm-101-runner/cloud-init.yaml") &&
      endswith(try(output.vm_configs.sandbox.cloud_init, ""), "/configs/vm-220-sandbox/cloud-init.yaml")
    )
    error_message = "cloud_init_paths output should map each VM to its generated cloud-init file"
  }
}

run "test_deploy_requires_ssh_key_when_enabled" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm-config"
  }

  variables {
    vms = {
      sandbox = {
        vmid       = 220
        hostname   = "sandbox"
        ip_address = "192.168.50.220"
        deploy     = false
      }
    }

    deploy_vm_configs = true
    ssh_private_key   = "   "
  }

  expect_failures = [
    check.deploy_requires_ssh_key,
  ]
}

run "test_deploy_with_ssh_key_passes_check" {
  command = plan

  module {
    source = "../../../modules/proxmox/vm-config"
  }

  variables {
    vms = {
      sandbox = {
        vmid       = 220
        hostname   = "sandbox"
        ip_address = "192.168.50.220"
        deploy     = false
      }
    }

    deploy_vm_configs = true
    ssh_private_key   = "mock-ssh-key-for-testing-only" # pragma: allowlist secret
  }

  assert {
    condition     = length(keys(output.vm_configs)) == 1
    error_message = "deploy_vm_configs=true with ssh_private_key should pass deploy_requires_ssh_key check"
  }
}
