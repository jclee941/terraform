# Cloudflare Tunnel — Synology NAS

Runs `cloudflared` as a Docker container on the Synology NAS to establish a secure tunnel to Cloudflare.

## Architecture

```
CF Edge → CF Tunnel → cloudflared (this container) → Synology DSM API (localhost:5001)
```

## Setup

### 1. Get Tunnel Token

After applying Terraform:

```bash
cd ../../terraform
terraform output -raw tunnel_token
```

### 2. Create `.env` File

```bash
cp .env.example .env
# Edit .env and paste the tunnel token
```

### 3. Deploy

```bash
# SSH into Synology NAS
ssh admin@192.168.50.215

# Navigate to this directory (or copy files)
cd /volume1/docker/cloudflared

# Start the tunnel
docker compose up -d

# Verify it's running
docker compose logs -f
```

## Operations

```bash
# Check status
docker compose ps

# View logs
docker compose logs -f cloudflared

# Restart
docker compose restart

# Update cloudflared
docker compose pull && docker compose up -d

# Stop
docker compose down
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `ERR Failed to connect` | Invalid token | Re-run `terraform output -raw tunnel_token` |
| `connection refused` | DSM not running on 5001 | Check DSM HTTPS port in Control Panel |
| Container restarts | Network issue | Check `docker compose logs` for details |
