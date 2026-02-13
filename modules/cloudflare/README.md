# Cloudflare Terraform Module

## Overview
Terraform module for managing Cloudflare infrastructure:
- Zero Trust Tunnels (cloudflared)
- Access Applications and Policies
- R2 Buckets
- Workers Scripts with bindings
- DNS Records

## Requirements
- Terraform >= 1.0
- Cloudflare Provider ~> 5.0

## Usage

```hcl
module "cloudflare" {
  source = "./modules/cloudflare"

  cloudflare_api_token  = var.cloudflare_api_token
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_id    = var.cloudflare_zone_id

  tunnels = {
    homelab = {
      name = "homelab"
      config = {
        ingress = [
          {
            hostname = "app.example.com"
            service  = "http://192.168.50.100:8080"
          },
          {
            service = "http_status:404"
          }
        ]
      }
    }
  }

  access_applications = {
    app = {
      name   = "My Application"
      domain = "app.example.com"
    }
  }

  access_policies = {
    allow_email = {
      application_id = module.cloudflare.access_application_ids["app"]
      name           = "Allow specific email"
      decision       = "allow"
      precedence     = 1
      include = [{
        email = ["user@example.com"]
      }]
    }
  }

  r2_buckets = {
    storage = {
      name     = "my-storage-bucket"
      location = "WNAM"
    }
  }
}
```

## Inputs

### Required
- `cloudflare_api_token` - Cloudflare API Token
- `cloudflare_account_id` - Cloudflare Account ID
- `cloudflare_zone_id` - Cloudflare Zone ID

### Optional
- `tunnels` - Map of Zero Trust tunnels
- `access_applications` - Map of Access applications
- `access_policies` - Map of Access policies
- `r2_buckets` - Map of R2 buckets
- `workers` - Map of Workers scripts
- `worker_routes` - Map of Workers routes
- `dns_records` - Map of DNS records

## Outputs
- `tunnel_ids` - Map of tunnel IDs
- `tunnel_tokens` - Map of tunnel tokens (sensitive)
- `tunnel_cnames` - Map of tunnel CNAME targets
- `access_application_ids` - Map of access application IDs
- `r2_bucket_names` - Map of R2 bucket names
- `worker_script_names` - Map of worker script names

## Notes
- Tunnel secrets are auto-generated if not provided
- DNS CNAMEs are automatically created for tunnels
- Workers bindings support: R2, KV, D1, secrets, plain text
