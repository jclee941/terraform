# GitLab Runner NFS Cache - Implementation Summary

## ✅ Infrastructure Changes (Complete)

All Terraform and infrastructure-as-code changes have been implemented.

### 1. Registry Routing (registry.jclee.me)

**File**: `100-pve/terraform/locals.tf`  
**Change**: Added `registry = "registry.yml.tftpl"` to Traefik template registry

This enables `registry.jclee.me` → Traefik (192.168.50.102) → Synology:5050

### 2. LXC Module Enhancement

**Files Modified**:
- `modules/proxmox/lxc/variables.tf` - Added `mount_points` variable
- `modules/proxmox/lxc/main.tf` - Added dynamic `mount_point` block
- `100-pve/terraform/main.tf` - Pass mount_points to module
- `100-pve/terraform/locals.tf` - Configure mount for gitlab-runner

**Mount Configuration**:
- Host path: `/mnt/gitlab-runner-cache`
- LXC path: `/srv/gitlab-runner/cache`
- LXC ID: 101 (gitlab-runner)

### 3. GitLab Runner Setup Script

**File**: `101-runner/scripts/setup-gitlab-runner-with-cache.go`  
**Features**:
- Automatic cache directory creation
- Runner config.toml with cache configuration
- Local cache type pointing to NFS mount
- Concurrent job support
- Systemd service installation

### 4. Helper Scripts

**File**: `scripts/setup-nfs-cache-proxmox.sh`  
**Purpose**: Automated NFS setup on Proxmox host

## 🚀 Deployment Steps

### Phase 1: Synology NFS Setup (Manual)

Run on Synology NAS (192.168.50.215):

```bash
# SSH into Synology
ssh admin@192.168.50.215

# Create shared folder for cache
sudo synoshare --add gitlab-runner-cache "GitLab Runner Cache" /volume1/gitlab-runner-cache

# Enable NFS export
sudo synoshare --setnfs gitlab-runner-cache enable

# Allow 192.168.50.0/24 network access
sudo synonfsext --add-rule gitlab-runner-cache 192.168.50.0/24 rw

# Verify
sudo showmount -e localhost
```

### Phase 2: Proxmox NFS Mount (Script)

Copy and run `scripts/setup-nfs-cache-proxmox.sh` on Proxmox host (192.168.50.100):

```bash
# From your workstation
scp scripts/setup-nfs-cache-proxmox.sh root@192.168.50.100:/tmp/
ssh root@192.168.50.100 'bash /tmp/setup-nfs-cache-proxmox.sh'
```

Or run manually:
```bash
# On Proxmox host
mkdir -p /mnt/gitlab-runner-cache
mount -t nfs -o nfsvers=4.1,hard,noatime \
    192.168.50.215:/volume1/gitlab-runner-cache /mnt/gitlab-runner-cache
echo "192.168.50.215:/volume1/gitlab-runner-cache /mnt/gitlab-runner-cache nfs _netdev,x-systemd.automount,hard,noatime 0 0" >> /etc/fstab
```

### Phase 3: Apply Terraform

```bash
cd /path/to/terraform
make plan SVC=pve
# Review and apply via CI/CD
```

This will:
- Render `registry.yml` for Traefik
- Add mount point to LXC 101 config

### Phase 4: Setup GitLab Runner (Script)

Copy and run the updated setup script inside LXC 101:

```bash
# From Proxmox host
pct exec 101 -- mkdir -p /opt/runner/scripts
scp 101-runner/scripts/setup-gitlab-runner-with-cache.go root@192.168.50.101:/opt/runner/scripts/
ssh root@192.168.50.101 'cd /opt/runner/scripts && go run setup-gitlab-runner-with-cache.go'
```

### Phase 5: Verification

```bash
# Test NFS mount on Proxmox
df -h /mnt/gitlab-runner-cache
ls -la /mnt/gitlab-runner-cache

# Test mount inside LXC 101
pct exec 101 -- df -h /srv/gitlab-runner/cache
pct exec 101 -- touch /srv/gitlab-runner/cache/test && pct exec 101 -- rm /srv/gitlab-runner/cache/test

# Test registry routing
curl -I https://registry.jclee.me

# Check runner config
pct exec 101 -- cat /etc/gitlab-runner/config.toml | grep -A5 "cache"
```

## 📁 Files Changed

| File | Lines Changed | Purpose |
|------|---------------|---------|
| `100-pve/terraform/locals.tf` | +1 | Add registry template + mount_points config |
| `100-pve/terraform/main.tf` | +1 | Pass mount_points to LXC module |
| `modules/proxmox/lxc/variables.tf` | +10 | Add mount_points variable with validation |
| `modules/proxmox/lxc/main.tf` | +8 | Add dynamic mount_point block |
| `101-runner/scripts/setup-gitlab-runner-with-cache.go` | +439 | New runner setup with cache support |
| `scripts/setup-nfs-cache-proxmox.sh` | +143 | Proxmox NFS setup script |
| `docs/runbooks/gitlab-runner-nfs-cache.md` | +227 | Complete runbook documentation |

## 🔧 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Synology NAS (192.168.50.215)             │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  NFS Export: /volume1/gitlab-runner-cache                │   │
│  │  Permissions: 192.168.50.0/24 (RW)                       │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │ NFS v4.1
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Proxmox Host (192.168.50.100)                │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Mount: /mnt/gitlab-runner-cache                         │   │
│  │  fstab: _netdev,x-systemd.automount,hard,noatime         │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │ Bind Mount
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  LXC 101 - GitLab Runner (192.168.50.101)        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Mount: /srv/gitlab-runner/cache                         │   │
│  │  Owner: gitlab-runner:gitlab-runner                      │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │ Volume Mount
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Docker Build Jobs                            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Cache Type: local                                       │   │
│  │  Cache Path: /cache → /srv/gitlab-runner/cache           │   │
│  │  BuildKit: cache-to/cache-from local filesystem          │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## ⚠️ Known Limitations

1. **Synology NFS**: Requires manual setup (no Terraform resource available)
2. **Proxmox Mount**: Requires SSH access to run setup script
3. **Runner Registration**: Requires `GITLAB_RUNNER_TOKEN` environment variable

## 📚 References

- [GitLab Runner Cache Documentation](https://docs.gitlab.com/runner/configuration/cache.html)
- [Proxmox LXC Mount Points](https://pve.proxmox.com/wiki/Linux_Container#_bind_mount_points)
- [NFS Best Practices](https://docs.oracle.com/cd/E19436-01/820-6433/fsfilesysconcept-97378/index.html)

---

**Status**: Infrastructure ready. Pending manual execution on hardware.
