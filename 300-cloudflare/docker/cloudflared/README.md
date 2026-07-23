# Cloudflare Tunnel Connector — Native Runtime

## Overview

The active `cloudflared` connector runs as a native systemd service on the cliproxy VM (VMID 114). This directory contains the retired Docker-on-Synology reference and is not the active deployment path.

## Architecture

#### Diagram summary 1

- Type: flowchart
- Internet -> Cloudflare Edge (CF)
- Cloudflare Edge (CF) -> Cloudflare Tunnel (Tunnel)
- Cloudflare Tunnel (Tunnel) -> native cloudflared service (cliproxy)
- native cloudflared service (cliproxy) -> configured tunnel origins


## Source of Truth

- **Terraform workspace**: `../../terraform/` (tunnel configuration and token output)
- **Active connector host**: cliproxy VM (VMID 114)
- **Legacy files**: `docker-compose.yml` and `.env.example` in this directory are not used by the active service.

## Operations

### Check the Active Connector

```bash
ssh root@cliproxy 'systemctl status cloudflared --no-pager'
ssh root@cliproxy 'journalctl -u cloudflared -n 50 --no-pager'
```

### Restart

```bash
ssh root@cliproxy 'systemctl restart cloudflared'
ssh root@cliproxy 'systemctl is-active cloudflared'
```

### Legacy Docker Reference

Do not deploy the connector on Synology with the compose files in this directory. Use the native systemd service on cliproxy instead.

## Safety Notes

- Never commit `.env` or tunnel tokens to git.
- If the service fails to connect, inspect `journalctl -u cloudflared` on cliproxy and verify the Terraform-managed tunnel configuration.
- Synology remains a tunnel origin at `192.168.50.215:5000`; it does not host the active connector.
