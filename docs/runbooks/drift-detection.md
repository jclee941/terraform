# Drift Detection Runbook

**Purpose:** Detect and reconcile Terraform state drift  
**Scope:** All Terraform workspaces in the homelab  
**Frequency:** Automated (Mon-Fri 00:00 UTC) + Manual (on-demand)  
**Owner:** Infrastructure Team  

---

## Overview

Drift occurs when the actual infrastructure state differs from the Terraform state file. This can happen due to:

- Manual changes via Proxmox UI or API
- External automation modifying resources
- Failed Terraform applies leaving partial state
- Infrastructure failures and recoveries

This runbook describes how drift is detected and reconciled.

---

## Automated Drift Detection

### Schedule
- **When:** Monday–Friday at 00:00 UTC
- **Pipeline:** `.gitlab/ci/60-drift-detection.yml`
- **Job:** `drift:detection`

### Process
1. Scheduled pipeline triggers automatically
2. For each managed workspace:
   - Run `terraform init`
   - Run `terraform plan -detailed-exitcode`
3. Interpret exit codes:
   - `0`: No drift (no changes)
   - `1`: Error during planning
   - `2`: Drift detected (changes present)

### Alerting
When drift is detected (exit code 2):
- GitLab issue auto-created with label `drift`
- Issue assigned to `@infrastructure-team`
- Issue includes:
  - Workspace name
  - Resources with drift
  - Plan output (truncated)
  - Timestamp
  - Link to pipeline

### Issue Template
```markdown
Title: [DRIFT] {workspace} - {timestamp}

## Summary
Drift detected in workspace: {workspace}

## Affected Resources
{plan_output}

## Pipeline
{pipeline_url}

## Action Required
1. Review drift in pipeline logs
2. Determine if drift is intentional or unexpected
3. Follow reconciliation procedure below

/label ~drift ~infrastructure
/assign @infrastructure-team
```

---

## Manual Drift Detection

### Via GitLab Pipeline

1. Navigate to **CI/CD > Pipelines**
2. Click **Run pipeline**
3. Select branch: `master`
4. Add variable: `DRIFT_CHECK = true`
5. Click **Run pipeline**

### Via Local (Read-Only)

⚠️ **Note:** `make drift-check` is disabled. Use CI/CD for all drift checks.

```bash
# For emergency local check (read-only):
cd 100-pve
terraform plan -detailed-exitcode -refresh-only
# Exit codes: 0=no drift, 2=drift detected
```

---

## Drift Reconciliation

### Step 1: Identify Drift Source

Run plan to see what changed:

```bash
# In affected workspace
terraform plan -out=drift.tfplan
terraform show drift.tfplan
```

Check GitLab pipeline logs for:
- Which resources have changes
- Type of change (add, change, destroy)
- Who made the last change (if in Git history)

### Step 2: Classify the Drift

| Type | Description | Example |
|------|-------------|---------|
| **Intentional** | Manual change was required | Emergency disk expansion |
| **Unintentional** | Accidental or unknown change | Someone modified config via UI |
| **External** | Outside system caused change | Proxmox HA migration |
| **Bug** | Terraform/provider issue | Resource re-created unnecessarily |

### Step 3: Choose Reconciliation Method

#### Method A: Import Drift into Terraform (Intentional Change)

If the drift was intentional and should persist:

```bash
# Option 1: Update Terraform config to match reality
# Edit .tf files to reflect the actual state

# Option 2: Import the resource (if new)
terraform import {resource_type}.{name} {id}

# Then apply to update state
cd 100-pve
terraform plan
terraform apply
```

#### Method B: Revert Drift via Terraform (Unintentional Change)

If the drift was unintentional and should be reverted:

```bash
# Plan will show drift being reverted
cd 100-pve
terraform plan -out=fix.tfplan

# Review carefully - this will change infrastructure!
terraform show fix.tfplan

# Apply the fix
terraform apply fix.tfplan
```

#### Method C: Ignore Specific Drift (Expected Variations)

For drift that is expected and should be ignored:

```hcl
resource "proxmox_virtual_environment_lxc" "example" {
  # ... configuration ...

  lifecycle {
    ignore_changes = [
      # Ignore MAC address changes (assigned by Proxmox)
      network_interface[0].mac_address,
      # Ignore startup order changes
      startup,
    ]
  }
}
```

⚠️ **Warning:** Only ignore changes you fully understand. Document why.

---

## Common Drift Scenarios

### Scenario 1: Proxmox HA Migration

**Symptom:** LXC/VM shows `node_name` change  
**Cause:** Proxmox HA moved container to different node  
**Resolution:**

```hcl
lifecycle {
  ignore_changes = [
    node_name,  # Allow HA to manage placement
  ]
}
```

### Scenario 2: Manual Disk Expansion

**Symptom:** Disk size differs from Terraform config  
**Cause:** Emergency disk expansion via Proxmox UI  
**Resolution:**

Option A (keep expansion):
```bash
# Update Terraform config to match new size
# Edit locals.tf or container definition
terraform apply  # Import the change
```

Option B (revert expansion - RISKY):
```bash
# This will shrink the disk!
terraform apply  # Reverts to Terraform-defined size
```

### Scenario 3: Cloudflare DNS Change

**Symptom:** DNS record differs from Terraform  
**Cause:** Manual DNS edit in Cloudflare dashboard  
**Resolution:**

Always use Terraform for DNS changes:
```bash
# Update 300-cloudflare/main.tf with correct records
terraform apply
```

### Scenario 4: Configuration File Modified on Host

**Symptom:** Service config differs from template  
**Cause:** Manual edit in `/opt/{service}/`  
**Resolution:**

```bash
# Configs are managed by 100-pve/config-renderer
# Update source template in {service}/templates/
# Then apply 100-pve to regenerate and deploy
cd 100-pve
terraform apply -target=module.config_renderer
```

---

## Prevention

### Do's

✅ **Do** use Terraform for all infrastructure changes  
✅ **Do** use `make plan` before any change to see impact  
✅ **Do** document emergency manual changes in GitLab issue  
✅ **Do** use `lifecycle { ignore_changes = [...] }` for expected variations  
✅ **Do** review drift detection issues promptly  

### Don'ts

❌ **Don't** use Proxmox UI for routine changes  
❌ **Don't** manually edit `/opt/{service}/` configs  
❌ **Don't** use Cloudflare dashboard for DNS changes  
❌ **Don't** ignore drift alerts for >24 hours  
❌ **Don't** run `terraform apply` without reviewing plan  

### Best Practices

1. **Use CI/CD:** All changes should go through GitLab pipeline
2. **Immutable Infrastructure:** Recreate rather than modify when possible
3. **Document Exceptions:** If manual change required, create GitLab issue
4. **Regular Review:** Weekly review of drift detection issues
5. **Test in Dev:** Test changes in non-prod before applying to prod

---

## Emergency Contacts

| Role | Contact | When to Contact |
|------|---------|-----------------|
| Infrastructure Lead | @infrastructure-lead | Unexplained drift, potential security issue |
| On-Call Engineer | On-call rotation | Critical service drift, outage risk |
| Proxmox Admin | @proxmox-admin | Hypervisor-level drift |

---

## Related Documentation

- [Architecture Overview](/ARCHITECTURE.md)
- [State Management](/docs/runbooks/state-locking.md)
- [Backup and Restore](/docs/runbooks/backup-restore.md)
- [Service Deployment](/docs/runbooks/service-deployment.md)
- [GitLab CI Pipeline](/.gitlab-ci.yml)

---

## Change Log

| Date | Author | Change |
|------|--------|--------|
| 2026-03-31 | Infrastructure Team | Initial version |

---

## References

- Terraform Drift Detection: https://developer.hashicorp.com/terraform/tutorials/state/resource-drift
- GitLab CI Scheduled Pipelines: https://docs.gitlab.com/ee/ci/pipelines/schedules.html
- Proxmox HA: https://pve.proxmox.com/wiki/High_Availability
