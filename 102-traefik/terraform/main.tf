locals {
  hosts = try(data.terraform_remote_state.infra.outputs.host_inventory, {})
}
