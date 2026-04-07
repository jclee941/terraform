# SSH Key Setup for CI/CD Deployment

This guide configures SSH keys for automated deployment from GitLab CI to your infrastructure hosts.

## Overview

The CI/CD pipeline (`.gitlab/ci/45-nfs-cache-deploy.yml`) requires SSH access to:
- **Synology NAS** (192.168.50.215) - root user
- **Proxmox Host** (192.168.50.100) - root user

## Setup Steps

### 1. Generate Deployment Key

From your workstation:

```bash
# Generate a dedicated deployment key
ssh-keygen -t ed25519 -C "gitlab-deploy@jclee.me" -f ~/.ssh/gitlab-deploy

# Copy public key to clipboard
cat ~/.ssh/gitlab-deploy.pub | xclip -selection clipboard
```

### 2. Add to Synology

```bash
ssh root@192.168.50.215

# Create .ssh directory if needed
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Add public key
echo "ssh-ed25519 AAAAC3NzaC... gitlab-deploy@jclee.me" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
```

### 3. Add to Proxmox

```bash
ssh root@192.168.50.100

# Create .ssh directory if needed
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Add public key
echo "ssh-ed25519 AAAAC3NzaC... gitlab-deploy@jclee.me" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
```

### 4. Configure GitLab CI/CD Variable

In GitLab UI:
1. Go to **Project Settings** → **CI/CD** → **Variables**
2. Click **Add Variable**
3. Configure:
   - **Key**: `DEPLOY_SSH_KEY`
   - **Value**: Paste the content of `~/.ssh/gitlab-deploy` (private key)
   - **Type**: **File** (important!)
   - **Protect variable**: ✅ (checked)
   - **Mask variable**: ✅ (checked)

### 5. Test SSH Access

From your workstation:

```bash
# Test Synology
ssh -i ~/.ssh/gitlab-deploy root@192.168.50.215 "echo 'Synology OK'"

# Test Proxmox
ssh -i ~/.ssh/gitlab-deploy root@192.168.50.100 "echo 'Proxmox OK'"
```

### 6. Run CI Deployment

Once keys are configured, trigger deployment from GitLab:

1. Go to **CI/CD** → **Pipelines**
2. Click **Run pipeline** on the default branch
3. Select the deployment job:
   - `deploy-nfs-cache-all` - Complete deployment (recommended)
   - `deploy-nfs-synology` - Synology only
   - `deploy-nfs-proxmox` - Proxmox/LXC only
   - `deploy-gitlab-runner` - Runner setup only

Or from command line:

```bash
# Trigger via API (requires GitLab token)
curl -X POST \
  -F token=$CI_JOB_TOKEN \
  -F ref=master \
  -F "variables[DEPLOY_STEP]=all" \
  https://gitlab.jclee.me/api/v4/projects/1/trigger/pipeline
```

## Security Notes

- **Never commit** the private key to the repository
- The `DEPLOY_SSH_KEY` variable is masked in CI logs
- The key is only loaded during CI execution
- Use `StrictHostKeyChecking=no` in CI for non-interactive deployment
- Consider restricting SSH access by IP if possible:
  ```bash
  # Add to /etc/ssh/sshd_config
  Match User root Address 192.168.50.0/24
      PubkeyAuthentication yes
  ```

## Troubleshooting

### Permission Denied

```bash
# Check key is added correctly
ssh -v -i ~/.ssh/gitlab-deploy root@192.168.50.100

# Verify authorized_keys permissions on remote host
ssh root@192.168.50.100 "ls -la /root/.ssh/"
# Should show: -rw------- for authorized_keys
```

### Host Key Verification Failed

This is expected in CI with `StrictHostKeyChecking=no`. For local testing:

```bash
# Add to ~/.ssh/config
Host 192.168.50.*
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

### CI Variable Not Working

Ensure the variable type is **File** not **Variable**:
- **File**: Creates a temporary file with the key content
- **Variable**: Sets an environment variable (not suitable for multi-line keys)

## Alternative: Manual Deployment

If you prefer not to use CI/CD for deployment, use the local deployment script:

```bash
# Ensure you have SSH key authentication set up
ssh-add ~/.ssh/id_ed25519

# Run deployment from your workstation
go run scripts/deploy-nfs-cache.go --step=all -v
```

This script requires passwordless SSH to both hosts.
