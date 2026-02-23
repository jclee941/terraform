# PVE Bare-Metal Filebeat Deployment

## Scope

- In scope: Install Filebeat 8.12.0 on PVE bare-metal host (192.168.50.100), deploy config, verify ELK ingestion.
- Out of scope: Terraform-managed LXC/VM hosts (use `setup_filebeat = true` in `100-pve/main.tf`).

## Inputs and Constraints

- PVE host is **not** Terraform-provisioned. Filebeat must be installed manually.
- Config source of truth: `100-pve/config/filebeat.yml`
- ELK endpoint: `192.168.50.105:5044` (Logstash beats input)
- ILM tier: `logs-critical` (90d retention) — PVE is critical infrastructure
- Filebeat version must match other hosts: **8.12.0**

## Prerequisites

1. SSH access to PVE host as root.
2. ELK stack (LXC 105) is running and healthy.
3. `100-pve/config/filebeat.yml` is up to date in git.

## Deployment Steps

### 1. Copy and run the install script

```bash
# From your workstation (or runner)
scp scripts/setup-filebeat.sh root@192.168.50.100:/tmp/setup-filebeat.sh
ssh root@192.168.50.100 'bash /tmp/setup-filebeat.sh'
```

**Expected output**: Filebeat 8.12.0 installed, systemd service enabled.

### 2. Deploy the Filebeat config

```bash
scp 100-pve/config/filebeat.yml root@192.168.50.100:/etc/filebeat/filebeat.yml
ssh root@192.168.50.100 'systemctl restart filebeat'
```

### 3. Verify Filebeat is running

```bash
ssh root@192.168.50.100 'systemctl status filebeat --no-pager'
ssh root@192.168.50.100 'filebeat version'
```

**Expected**: Active (running), version 8.12.0.

### 4. Verify ELK ingestion

```bash
# On ELK host (LXC 105) — check for fresh pve documents
curl -s -u elastic:$ELASTIC_PASSWORD \
  "localhost:9200/logs-pve-*/_search" \
  -H 'Content-Type: application/json' \
  -d '{
    "size": 1,
    "sort": [{"@timestamp": "desc"}],
    "query": {
      "range": {
        "@timestamp": {
          "gte": "now-5m",
          "lte": "now"
        }
      }
    },
    "_source": ["@timestamp", "service", "message", "host.name"]
  }'
```

**Expected**: At least 1 hit with `service: pve`.

### 5. Verify ILM binding

```bash
curl -s -u elastic:$ELASTIC_PASSWORD \
  "localhost:9200/logs-pve-*/_settings" \
  | jq 'to_entries[] | {index: .key, ilm: .value.settings.index.lifecycle.name}'
```

**Expected**: `ilm: homelab-logs-critical-90d`.

## Rollback

```bash
ssh root@192.168.50.100 'systemctl stop filebeat && systemctl disable filebeat'
```

To fully remove:

```bash
ssh root@192.168.50.100 'apt-get remove -y filebeat'
```

## Completion Record

- Service: `pve`
- Tier: `critical-90d`
- Filebeat installed: `yes/no`
- Config deployed: `yes/no`
- Fresh event observed in last 5m: `yes/no`
- ILM binding confirmed: `yes/no`
- Verified by: `<name>`
- Date: `<YYYY-MM-DD>`
