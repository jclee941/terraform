# Cloudflare Secrets Store support is currently in beta and provider coverage can lag.
# The store already exists, so we reference its ID and keep Terraform-side structure ready.
# Secret writes are implemented with a guarded local-exec workflow using Wrangler CLI.

resource "terraform_data" "cf_secrets_store" {
  input = {
    account_id = var.cloudflare_account_id
    store_id   = var.cloudflare_secrets_store_id
    secrets    = local.cf_store_secrets
  }
}

resource "terraform_data" "cf_store_secret_sync" {
  for_each = var.enable_cf_store_sync ? {
    for name in local.cf_store_secrets : name => name
  } : {}

  input = {
    account_id  = var.cloudflare_account_id
    store_id    = var.cloudflare_secrets_store_id
    secret_name = each.key
  }

  lifecycle {
    precondition {
      condition     = var.enable_cf_store_sync ? contains(keys(var.secret_values), each.key) : true
      error_message = "Missing var.secret_values entry for ${each.key}."
    }
  }

  provisioner "local-exec" {
    when        = create
    command     = <<-EOT
      if [ "${var.enable_cf_store_sync}" != "true" ]; then
        echo "Skipping CF Secrets Store sync for ${each.key} (enable_cf_store_sync=false)"
        exit 0
      fi

      if ! command -v wrangler >/dev/null 2>&1; then
        echo "wrangler CLI is required to sync CF Secrets Store secrets" >&2
        exit 1
      fi

      printf '%s' "${var.secret_values[each.key]}" | wrangler secrets-store secret create "${each.key}" \
        --store-id "${var.cloudflare_secrets_store_id}" \
        --account-id "${var.cloudflare_account_id}" \
        --remote
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}
