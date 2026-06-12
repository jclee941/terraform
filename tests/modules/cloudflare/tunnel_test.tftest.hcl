mock_provider "cloudflare" {
  override_resource {
    target          = cloudflare_zero_trust_tunnel_cloudflared.this
    override_during = plan
    values = {
      account_tag       = "mock-account-tag"
      config_src        = "cloudflare"
      conns_active_at   = "2026-01-01T00:00:00Z"
      conns_inactive_at = "2026-01-01T00:00:00Z"
      created_at        = "2026-01-01T00:00:00Z"
      deleted_at        = ""
      id                = "mock-tunnel-id"
      metadata          = ""
      remote_config     = true
      status            = "healthy"
      tun_type          = "cfd_tunnel"
    }
  }

  override_resource {
    target          = cloudflare_zero_trust_tunnel_cloudflared_config.this
    override_during = plan
    values = {
      created_at = "2026-01-01T00:00:00Z"
      id         = "mock-tunnel-config-id"
      source     = "cloudflare"
      version    = 1
    }
  }

  override_data {
    target          = data.cloudflare_zero_trust_tunnel_cloudflared_token.this
    override_during = plan
    values = {
      token = "mock-tunnel-token"
    }
  }
}

mock_provider "random" {}

run "test_tunnel_outputs" {
  command = apply

  module {
    source = "../../../modules/cloudflare/tunnel"
  }

  variables {
    name       = "test-tunnel"
    account_id = "abcdef0123456789abcdef0123456789"
    ingress = [
      {
        hostname = "example.jclee.me"
        service  = "http://localhost:80"
      },
      {
        service = "http_status:404"
      },
    ]
  }

  assert {
    condition     = output.tunnel_id == "mock-tunnel-id"
    error_message = "Tunnel ID output should expose the Cloudflare tunnel ID."
  }

  assert {
    condition     = nonsensitive(output.tunnel_token) == "mock-tunnel-token"
    error_message = "Tunnel token output should expose the cloudflared token."
  }
}
