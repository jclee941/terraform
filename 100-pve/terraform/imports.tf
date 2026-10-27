import {
  to = module.lxc["cliproxy"].proxmox_virtual_environment_container.this
  id = "pve3/114"
}

moved {
  from = module.vm["youtube"]
  to   = module.vm["jclee-prd"]
}

moved {
  from = module.vm_config.local_file.cloud_init["youtube"]
  to   = module.vm_config.local_file.cloud_init["jclee-prd"]
}

moved {
  from = module.vm_config.null_resource.install_filebeat["youtube"]
  to   = module.vm_config.null_resource.install_filebeat["jclee-prd"]
}

moved {
  from = module.vm_config.null_resource.deploy_vm_write_files["youtube-0"]
  to   = module.vm_config.null_resource.deploy_vm_write_files["jclee-prd-0"]
}

moved {
  from = module.vm_config.null_resource.deploy_vm_write_files["youtube-1"]
  to   = module.vm_config.null_resource.deploy_vm_write_files["jclee-prd-1"]
}

moved {
  from = module.vm_config.null_resource.deploy_vm_write_files["youtube-2"]
  to   = module.vm_config.null_resource.deploy_vm_write_files["jclee-prd-2"]
}

moved {
  from = module.vm_config.null_resource.deploy_vm_write_files["youtube-3"]
  to   = module.vm_config.null_resource.deploy_vm_write_files["jclee-prd-3"]
}
