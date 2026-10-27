# Archived ELK Configuration

This directory contains inactive configuration snapshots kept only for historical comparison.

The active deployment path is:

```text
105-elk/templates/*.tftpl
  -> modules/proxmox/config-renderer
  -> 100-pve/terraform/configs/rendered/elk/
  -> /opt/elk/
```

Do not deploy, edit, or synchronize files under `105-elk/legacy/`. Make production changes in `105-elk/templates/` and deploy them through the Terraform pipeline.
