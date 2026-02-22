# Synology DSM Syslog Forwarding to ELK

This host is inventory-only and is not Terraform-provisioned (`215-synology/AGENTS.md`).
Configure forwarding in DSM UI using endpoint values from `100-pve/envs/prod/hosts.tf`.

## Endpoint Source of Truth

- ELK target host: `local.hosts.elk.ip = 192.168.50.105`
- Logstash syslog port: `local.hosts.elk.ports.logstash_tcp = 5000`
- Synology host key: `local.hosts.synology` (`192.168.50.215`)

## DSM Configuration Steps

1. Sign in to DSM as an administrator.
2. Open `Log Center`.
3. Go to `Log Sending` (or `Log Center` -> `Settings` -> `Log Sending`, depending on DSM version).
4. Click `Create` (or `Add`) to add a new log forwarding server.
5. Set destination values:
   - Server: `192.168.50.105`
   - Port: `5000`
   - Protocol: `UDP` (or `TCP` if preferred in your DSM policy)
6. Enable forwarding for system and connection logs (and package logs when available).
7. Save and apply.

## Logstash Side Confirmation

`105-elk/templates/logstash.conf.tftpl` already defines:

- `syslog { port => 5000 type => "syslog" }`

Events can be indexed by service naming logic as `logs-<service>-YYYY.MM.dd`. For Synology forwarding, use service tag `synology` when source metadata supports tagging.

## Verification Command

Run on ELK host (LXC 105) after enabling DSM forwarding:

```bash
docker exec -it logstash bin/logstash -t -f /usr/share/logstash/pipeline/logstash.conf
```

Optional network check from an internal host:

```bash
nc -vz 192.168.50.105 5000
```
