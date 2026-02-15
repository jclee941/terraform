# Given one template entry, when apply runs, then content matches expected render.
run "test_single_template_rendering" {
  command = apply

  module {
    source = "../../../modules/proxmox/config-renderer"
  }

  variables {
    template_vars = {
      service_name = "elasticsearch"
      host_ip      = "192.168.50.105"
      port         = 9200
      enabled      = true
    }

    template_files = {
      test_config = {
        source = "fixtures/test.yml.tftpl"
        output = "single-test-config.yml"
      }
    }

    output_dir = "fixtures"
  }

  assert {
    condition = trimspace(output.rendered_configs["test_config"]) == trimspace(<<-EOT
      # Test config for elasticsearch
      host: 192.168.50.105
      port: 9200
      enabled: true
    EOT
    )
    error_message = "Single template content did not match expected render."
  }
}

# Given multiple template entries, when apply runs, then each output is rendered independently.
run "test_multiple_templates" {
  command = apply

  module {
    source = "../../../modules/proxmox/config-renderer"
  }

  variables {
    template_vars = {
      service_name = "grafana"
      host_ip      = "192.168.50.104"
      port         = 3000
      enabled      = true
    }

    template_files = {
      primary_config = {
        source = "fixtures/test.yml.tftpl"
        output = "multi-primary-config.yml"
      }
      secondary_config = {
        source = "fixtures/test.yml.tftpl"
        output = "multi-secondary-config.yml"
      }
    }

    output_dir = "fixtures"
  }

  assert {
    condition     = length(output.rendered_configs) == 2
    error_message = "Expected two rendered configs for multiple template test."
  }

  assert {
    condition = trimspace(output.rendered_configs["primary_config"]) == trimspace(<<-EOT
      # Test config for grafana
      host: 192.168.50.104
      port: 3000
      enabled: true
    EOT
    )
    error_message = "Primary template content did not render as expected."
  }

  assert {
    condition = trimspace(output.rendered_configs["secondary_config"]) == trimspace(<<-EOT
      # Test config for grafana
      host: 192.168.50.104
      port: 3000
      enabled: true
    EOT
    )
    error_message = "Secondary template content did not render as expected."
  }

  assert {
    condition     = output.rendered_files["primary_config"] != output.rendered_files["secondary_config"]
    error_message = "Expected unique output files for each rendered template."
  }
}

# Given configured output_dir and filename, when apply runs, then rendered_files contains full path.
run "test_output_file_paths" {
  command = apply

  module {
    source = "../../../modules/proxmox/config-renderer"
  }

  variables {
    template_vars = {
      service_name = "kibana"
      host_ip      = "192.168.50.105"
      port         = 5601
      enabled      = true
    }

    template_files = {
      path_config = {
        source = "fixtures/test.yml.tftpl"
        output = "path-test-config.yml"
      }
    }

    output_dir = "fixtures"
  }

  assert {
    condition     = strcontains(output.rendered_files["path_config"], "fixtures/path-test-config.yml")
    error_message = "Rendered file path did not include expected output_dir and filename."
  }
}

# Given a custom output_dir, when apply runs, then rendered file path reflects the override.
run "test_custom_output_dir" {
  command = apply

  module {
    source = "../../../modules/proxmox/config-renderer"
  }

  variables {
    template_vars = {
      service_name = "traefik"
      host_ip      = "192.168.50.102"
      port         = 80
      enabled      = true
    }

    template_files = {
      custom_path_config = {
        source = "fixtures/test.yml.tftpl"
        output = "custom-output-test-config.yml"
      }
    }

    output_dir = "."
  }

  assert {
    condition     = strcontains(output.rendered_files["custom_path_config"], "custom-output-test-config.yml") && !strcontains(output.rendered_files["custom_path_config"], "fixtures/")
    error_message = "Custom output_dir was not reflected in rendered_files output."
  }
}

# Given template vars, when templatefile renders, then all values are injected into output.
run "test_template_var_injection" {
  command = apply

  module {
    source = "../../../modules/proxmox/config-renderer"
  }

  variables {
    template_vars = {
      service_name = "mcphub"
      host_ip      = "192.168.50.112"
      port         = 5678
      enabled      = false
    }

    template_files = {
      injection_config = {
        source = "fixtures/test.yml.tftpl"
        output = "template-vars-test-config.yml"
      }
    }

    output_dir = "fixtures"
  }

  assert {
    condition = alltrue([
      strcontains(output.rendered_configs["injection_config"], "# Test config for mcphub"),
      strcontains(output.rendered_configs["injection_config"], "host: 192.168.50.112"),
      strcontains(output.rendered_configs["injection_config"], "port: 5678"),
      strcontains(output.rendered_configs["injection_config"], "enabled: false"),
    ])
    error_message = "One or more template variables were not injected into rendered output."
  }
}

# Given an empty template_files map, when apply runs, then outputs are empty maps.
run "test_empty_template_files" {
  command = apply

  module {
    source = "../../../modules/proxmox/config-renderer"
  }

  variables {
    template_vars  = {}
    template_files = {}
    output_dir     = "fixtures"
  }

  assert {
    condition     = length(output.rendered_configs) == 0 && length(output.rendered_files) == 0
    error_message = "Expected empty outputs when template_files is empty."
  }
}
