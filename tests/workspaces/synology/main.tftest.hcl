run "synology_host_requires_https" {
  command = plan

  variables {
    synology_host = "http://192.168.50.215:5001"
  }

  expect_failures = [var.synology_host]
}

run "synology_network_output_is_available" {
  command = plan

  variables {
    synology_host = "https://192.168.50.215:5001"
  }

  assert {
    condition     = output.service_url == "https://192.168.50.215:5001"
    error_message = "service_url output must expose the validated Synology HTTPS endpoint"
  }
}
