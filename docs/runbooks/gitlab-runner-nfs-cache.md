# GitLab Runner NFS Build Cache Setup

This guide documents the setup for Docker build cache using NFS on the GitLab Runner (LXC 101).

## Architecture

```
Synology NFS Export (/volume1/gitlab-runner-cache)
    ↓ NFS v4.1
Proxmox Host (pve3) mount at /mnt/gitlab-runner-cache
    ↓ Bind mount
LXC 101 (gitlab-runner) at /srv/gitlab-runner/cache
    ↓ Volume mount
GitLab Runner Docker executor jobs
```

## Infrastructure Changes (Terraform)

The following Terraform changes have been made:

1. **102-traefik/templates/registry.yml.tftpl** - Already existed, now registered in locals.tf
2. **modules/proxmox/lxc/main.tf** - Added `mount_point` dynamic block support
3. **modules/proxmox/lxc/variables.tf** - Added `mount_points` variable
4. **100-pve/terraform/main.tf** - Pass `mount_points` to LXC module
5. **100-pve/terraform/locals.tf** - Added mount_points for gitlab-runner container

## Manual Setup Steps

### Step 1: Create NFS Share on Synology (192.168.50.215)

Via DSM Web UI or SSH:

```bash
# SSH into Synology
ssh admin@192.168.50.215

# Create shared folder
sudo synoshare --add gitlab-runner-cache "GitLab Runner Cache" /volume1/gitlab-runner-cache

# Enable NFS export (NFS v4.1)
sudo synoshare --setnfs gitlab-runner-cache enable

# Set permissions for 192.168.50.0/24 network
sudo synonfsext --add-rule gitlab-runner-cache 192.168.50.0/24 rw

# Verify export
sudo showmount -e localhost
```

**DSM UI Path:** Control Panel → Shared Folder → Create → gitlab-runner-cache → Enable NFS → Permissions: 192.168.50.0/24 (Read/Write)

### Step 2: Mount NFS on Proxmox Host (pve3)

On the Proxmox hypervisor (192.168.50.100):

```bash
# SSH into Proxmox
ssh root@192.168.50.100

# Create mount point
mkdir -p /mnt/gitlab-runner-cache

# Install NFS client if needed
apt-get update && apt-get install -y nfs-common

# Test mount
mount -t nfs -o nfsvers=4.1,hard,noatime,rsize=1048576,wsize=1048576,timeo=600 192.168.50.215:/volume1/gitlab-runner-cache /mnt/gitlab-runner-cache

# Verify
ls -la /mnt/gitlab-runner-cache
df -h /mnt/gitlab-runner-cache

# Add to /etc/fstab for persistence
echo "192.168.50.215:/volume1/gitlab-runner-cache /mnt/gitlab-runner-cache nfs _netdev,x-systemd.automount,hard,noatime,rsize=1048576,wsize=1048576,timeo=600 0 0" >> /etc/fstab

# Enable systemd mount
systemctl daemon-reload
systemctl restart remote-fs.target
```

### Step 3: Apply Terraform Changes

```bash
# From your workstation
cd /path/to/terraform
make plan SVC=pve
make apply SVC=pve  # Or via CI/CD pipeline
```

This will:
- Render `registry.yml` for Traefik (enables registry.jclee.me routing)
- Add mount point to LXC 101 configuration

### Step 4: Verify LXC Mount

After Terraform apply:

```bash
# SSH into Proxmox and check LXC config
ssh root@192.168.50.100
cat /etc/pve/lxc/101.conf | grep mp

# Should show:
# mp0: /mnt/gitlab-runner-cache,mp=/srv/gitlab-runner/cache

# Restart container if needed
pct stop 101 && pct start 101

# Verify inside container
pct exec 101 -- ls -la /srv/gitlab-runner/cache
```

### Step 5: Configure GitLab Runner

Inside LXC 101:

```bash
# SSH into container
ssh root@192.168.50.101

# Verify mount is accessible
df -h /srv/gitlab-runner/cache
touch /srv/gitlab-runner/cache/test && rm /srv/gitlab-runner/cache/test

# Update runner configuration to use cache
# Edit /etc/gitlab-runner/config.toml and add:
# [[runners]]
#   [runners.cache]
#     Type = "local"
#     Path = "/srv/gitlab-runner/cache"
#   [runners.docker]
#     volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
```

## Verification

### Test 1: NFS Connectivity

```bash
# On Proxmox host
showmount -e 192.168.50.215
mount | grep gitlab-runner-cache
```

### Test 2: LXC Mount

```bash
# On Proxmox host
pct exec 101 -- mount | grep gitlab-runner
cat /etc/pve/lxc/101.conf | grep ^mp
```

### Test 3: Registry Routing

```bash
# Test registry.jclee.me resolves to Traefik
dig registry.jclee.me

# Test routing
curl -I https://registry.jclee.me
```

## Troubleshooting

### NFS Mount Fails

```bash
# Check NFS export on Synology
showmount -e 192.168.50.215

# Test from Proxmox
rpcinfo -p 192.168.50.215 | grep nfs

# Check firewall
iptables -L | grep 2049
```

### LXC Mount Not Working

```bash
# Check LXC config
pct config 101

# Check mount point exists on host
ls -la /mnt/gitlab-runner-cache

# Check unprivileged container mapping
cat /etc/subuid | grep root
```

### Registry Not Routing

```bash
# Check Traefik config
ssh root@192.168.50.100 'pct exec 102 -- cat /opt/traefik/config/registry.yml'

# Check router exists
curl -s http://192.168.50.102:8080/api/http/routers | jq '.[] | select(.name | contains("registry"))'
```

## Maintenance

### NFS Performance Tuning

Monitor cache directory size:

```bash
# On Synology
du -sh /volume1/gitlab-runner-cache

# Clean old cache (run periodically)
find /volume1/gitlab-runner-cache -type f -mtime +30 -delete
```

### Backup Considerations

The NFS cache is ephemeral build data. No backup required, but consider:
- Setting retention policies on Synology
- Monitoring disk usage
- Clearing cache if storage fills up

## References

- [Terraform NFS Setup](../100-pve/terraform/locals.tf)
- [LXC Module](../modules/proxmox/lxc/main.tf)
- [Traefik Registry Template](../102-traefik/templates/registry.yml.tftpl)
