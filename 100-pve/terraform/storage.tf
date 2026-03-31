# =============================================================================
# STORAGE — External storage backends (PBS, NFS, etc.)
# =============================================================================

resource "proxmox_virtual_environment_storage_pbs" "pbs" {
  count       = var.enable_pbs ? 1 : 0
  id          = "pbs"
  server      = module.onepassword_secrets.metadata["pbs_server"]
  datastore   = module.onepassword_secrets.metadata["pbs_datastore"]
  username    = module.onepassword_secrets.metadata["pbs_username"]
  password    = module.onepassword_secrets.secrets["pbs_password"]
  fingerprint = module.onepassword_secrets.metadata["pbs_fingerprint"]
  content     = ["backup"]
}
