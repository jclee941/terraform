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

### 4. Deployment Automation
- **GitLab CI/CD** (`.gitlab/ci/45-nfs-cache-deploy.yml`):
  - `deploy-nfs-synology` - Create NFS share on Synology (manual trigger)
  - `deploy-nfs-proxmox` - Mount NFS and configure LXC (manual trigger)
  - `deploy-gitlab-runner` - Setup GitLab Runner (manual trigger)
  - `deploy-nfs-cache-all` - Complete deployment in one job (manual trigger)

- **Local Scripts**:
  - `scripts/deploy-nfs-cache.go` - Local deployment orchestrator
  - `scripts/verify-nfs-cache.go` - Health check and verification
  - `scripts/setup-nfs-share-synology.go` - Synology share setup
  - `scripts/setup-nfs-cache-proxmox.go` - Proxmox NFS mount setup
  - `101-runner/scripts/setup-gitlab-runner-with-cache.go` - Runner setup

### 5. Documentation
- **Files Created**:
  - `docs/runbooks/gitlab-runner-nfs-cache.md` - Complete runbook
  - `docs/runbooks/ssh-setup-ci-deployment.md` - SSH key setup for CI
  - `IMPLEMENTATION_SUMMARY.md` - Technical summary

## 🚀 Quick Start - Choose Your Method

### Method 1: GitLab CI/CD (Recommended)

Prerequisites: SSH keys configured in CI/CD variables (see `docs/runbooks/ssh-setup-ci-deployment.md`)

1. **Go to GitLab** → CI/CD → Pipelines
2. **Click "Run pipeline"** on master branch
3. **Select deployment job:**
   - `deploy-nfs-cache-all` - Deploy everything at once ⭐ Recommended
   - Individual steps: `deploy-nfs-synology`, `deploy-nfs-proxmox`, `deploy-gitlab-runner`

### Method 2: Local Deployment Script

Prerequisites: SSH key access to both Synology and Proxmox as root

```bash
# Deploy everything
go run scripts/deploy-nfs-cache.go --step=all -v

# Or deploy individual steps
go run scripts/deploy-nfs-cache.go --step=synology -v
go run scripts/deploy-nfs-cache.go --step=proxmox -v
go run scripts/deploy-nfs-cache.go --step=runner -v

# Dry run (show commands without executing)
go run scripts/deploy-nfs-cache.go --step=all --dry-run
```

### Method 3: Manual Step-by-Step

See `docs/runbooks/gitlab-runner-nfs-cache.md` for detailed manual steps.

## 🔍 Verification

### Quick Health Check

```bash
# Check all components
go run scripts/verify-nfs-cache.go

# JSON output for automation
go run scripts/verify-nfs-cache.go --json

# Attempt to fix issues automatically
go run scripts/verify-nfs-cache.go --fix
```

### Manual Verification Commands

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

## 📋 Deployment Checklist

- [ ] SSH keys configured in GitLab CI/CD (for CI method)
- [ ] Local SSH access to Synology and Proxmox (for local method)
- [ ] Terraform changes reviewed and approved
- [ ] CI/CD pipeline triggered
- [ ] NFS share created on Synology
- [ ] NFS mounted on Proxmox host
- [ ] LXC 101 configured with mount point
- [ ] GitLab Runner installed and configured
- [ ] Cache directory writable inside LXC
- [ ] Registry routing verified
- [ ] Test CI job with cache enabled

## 🛠️ Troubleshooting

### NFS Mount Fails

```bash
# Check NFS server is running on Synology
ssh root@192.168.50.215 "synoservice --status nfsd"

# Check exports
showmount -e 192.168.50.215

# Manual mount test
ssh root@192.168.50.100 "mount -t nfs -o vers=4.1 192.168.50.215:/volume1/gitlab-runner-cache /mnt/gitlab-runner-cache"
```

### LXC Won't Start

```bash
# Check LXC config syntax
ssh root@192.168.50.100 "cat /etc/pve/lxc/101.conf"

# Check logs
ssh root@192.168.50.100 "cat /var/log/syslog | grep 101"
```

### GitLab Runner Not Active

```bash
# Check status inside LXC
pct exec 101 -- systemctl status gitlab-runner

# View logs
pct exec 101 -- journalctl -u gitlab-runner -n 50
```

## 📚 References

- Runbook: `docs/runbooks/gitlab-runner-nfs-cache.md`
- SSH Setup: `docs/runbooks/ssh-setup-ci-deployment.md`
- Implementation: `IMPLEMENTATION_SUMMARY.md`
- Scripts: 
  - `scripts/deploy-nfs-cache.go`
  - `scripts/verify-nfs-cache.go`
  - `scripts/setup-nfs-share-synology.go`
  - `scripts/setup-nfs-cache-proxmox.go`
  - `101-runner/scripts/setup-gitlab-runner-with-cache.go`

---

**Status**: ✅ Infrastructure ready. Deployment automation complete.

Last Updated: 2025-04-07
