# GitLab Runner NFS Cache - Deployment Status

## ✅ Completed (Infrastructure as Code)

### 1. Registry Routing (registry.jclee.me)
- **File**: `100-pve/terraform/locals.tf`
- **Change**: Added `registry = "registry.yml.tftpl"` to Traefik template registry
- **Effect**: Routes `registry.jclee.me` → Synology GitLab Registry (192.168.50.215:5050)

### 2. LXC Module Enhancement
- **Files**: 
  - `modules/proxmox/lxc/variables.tf` - Added `mount_points` variable with validation
  - `modules/proxmox/lxc/main.tf` - Added dynamic `mount_point` block
  - `modules/proxmox/lxc/README.md` - Auto-updated by terraform_docs
- **Effect**: LXC containers can now have bind mounts configured via Terraform

### 3. GitLab Runner Configuration
- **Files**:
  - `100-pve/terraform/locals.tf` - Added mount_points for gitlab-runner container
  - `100-pve/terraform/main.tf` - Pass mount_points to LXC module
- **Configuration**:
  - Host path: `/mnt/gitlab-runner-cache`
  - LXC path: `/srv/gitlab-runner/cache`
  - LXC ID: 101

### 4. GitLab Runner Setup Script
- **File**: `101-runner/scripts/setup-gitlab-runner-with-cache.go`
- **Features**:
  - Automatic cache directory setup
  - Runner registration with local cache configuration
  - Systemd service installation

### 5. Documentation & Scripts
- **Files Created**:
  - `docs/runbooks/gitlab-runner-nfs-cache.md` - Complete runbook
  - `scripts/setup-nfs-share-synology.go` - Synology share setup (Go)
  - `scripts/setup-nfs-cache-proxmox.go` - NFS mount setup (Go)
  - `IMPLEMENTATION_SUMMARY.md` - Technical summary

## ⏳ Pending Manual Steps

### Step 1: Create NFS Share on Synology
```bash
# SSH to Synology (192.168.50.215) as jclee
ssh jclee@192.168.50.215

# Run the Go setup script
go run scripts/setup-nfs-share-synology.go

# Or manually:
sudo synoshare --add gitlab-runner-cache "GitLab Runner Cache" /volume1/gitlab-runner-cache
sudo synoshare --setnfs gitlab-runner-cache enable
sudo synonfsext --add-rule gitlab-runner-cache 192.168.50.0/24 rw
```

### Step 2: Run Deployment Script on Proxmox
```bash
# From your workstation
scp scripts/setup-nfs-cache-proxmox.go root@192.168.50.100:/tmp/
ssh root@192.168.50.100 "cd /tmp && go run setup-nfs-cache-proxmox.go"
```

This script will:
- Mount NFS share on Proxmox host
- Configure LXC 101 mount point
- Restart LXC container
- Verify mount inside container

### Step 3: Setup GitLab Runner
```bash
# SSH into LXC 101
ssh root@192.168.50.101

# Or from Proxmox
pct exec 101 -- bash

# Run setup script
go run /opt/runner/scripts/setup-gitlab-runner-with-cache.go
```

### Step 4: Apply Terraform Changes
```bash
cd /path/to/terraform
make plan SVC=pve
# Review and apply via CI/CD pipeline
```

## 🔧 Verification Commands

```bash
# Test NFS share from Proxmox
showmount -e 192.168.50.215

# Check mount on Proxmox
df -h /mnt/gitlab-runner-cache

# Check LXC config
ssh root@192.168.50.100 "cat /etc/pve/lxc/101.conf | grep mp"

# Verify inside container
pct exec 101 -- df -h /srv/gitlab-runner/cache
pct exec 101 -- touch /srv/gitlab-runner/cache/test && pct exec 101 -- rm /srv/gitlab-runner/cache/test

# Test registry routing
curl -I https://registry.jclee.me
```

## 📊 Architecture

```
Synology (192.168.50.215)
  └─ /volume1/gitlab-runner-cache (NFS Export)
         │
         ▼ NFS v4.1
Proxmox (192.168.50.100)
  └─ /mnt/gitlab-runner-cache (Host Mount)
         │
         ▼ Bind Mount
LXC 101 (192.168.50.101)
  └─ /srv/gitlab-runner/cache (Container Path)
         │
         ▼ Volume Mount
GitLab Runner Docker Jobs
  └─ /cache (Docker Volume)
```

## ⚠️ Known Issues

1. **Synology NFS Share**: Must be created manually (no Terraform resource available)
2. **Proxmox SSH**: Requires root access to run deployment script
3. **Terraform Apply**: Must be done via CI/CD (local apply disabled)

## 📚 References

- Runbook: `docs/runbooks/gitlab-runner-nfs-cache.md`
- Implementation: `IMPLEMENTATION_SUMMARY.md`
- Scripts: 
  - `scripts/setup-nfs-share-synology.go`
  - `scripts/setup-nfs-cache-proxmox.go`

---

**Status**: Infrastructure ready. Pending manual execution on hardware.

Created: 2025-04-07
