# 200-oc: OpenCode AI Development Environment

## 1. Service Overview
- **Service Name**: OpenCode Dev Environment
- **Host IP**: `192.168.50.200` (VM)
- **Type**: QEMU Virtual Machine (KVM)
- **Purpose**: The primary workspace for all AI-driven development and infrastructure orchestration. It runs the OpenCode agent sessions, providing a secure, isolated, and highly performant environment for pair-programming and automation.
- **Current Status**: **Online**. Active memory usage ~64%.
- **Hardware Profile**: 
  - **CPU**: 8 Cores (Ryzen 9800X3D Passthrough)
  - **RAM**: 30GB allocated with swap.

## 2. Configuration Files
- **OpenCode Settings**: `/home/jclee/.config/opencode/opencode.json` - Defines active plugins, MCP server endpoints, and agent model mappings.
- **Agent Roles**: `/home/jclee/.config/opencode/oh-my-opencode.json` - Maps agent types (Sisyphus, Oracle) to specific LLM models.
- **Logging Pipeline**: `/etc/filebeat/filebeat.yml` - Ships session logs to Logstash (105) → Elasticsearch → Grafana (104).
- **Maintenance**: `/etc/cron.d/opencode-log-cleanup` - Automated daily pruning of old session transcripts.

## 3. Operations
### Lifecycle Commands
```bash
# Access the Dev VM
ssh oc

# OpenCode CLI
opencode                       # Start a new agentic session
opencode --version             # Check current binary version

# Monitor Log Shipper
systemctl status filebeat
journalctl -u filebeat -f
```

### Resource Management
```bash
# Check session log volume
du -sh ~/.local/share/opencode/log/

# Manual log cleanup (older than 3 days)
find ~/.local/share/opencode/log -name "*.log" -mtime +3 -delete
```

## 4. Dependencies
- **104-grafana**: Visualizes session logs shipped via Filebeat → ELK for centralized debugging.
- **112-mcphub**: The VM relies on the 170 tools hosted in MCPHub for filesystem and API operations.
- **102-traefik**: Provides secure SSH/HTTP access if configured for external tunneling.

## 5. Troubleshooting
### Common Issues
- **VM Freeze/Hang**: Often caused by Filebeat attempting to ship extremely large log lines (e.g., base64 images).
  - *Fix*: Ensure `max_bytes` is configured in `/etc/filebeat/filebeat.yml` to truncate oversized lines.
- **Memory Spike**: Occurs when multiple recursive AI thinking loops are active simultaneously.
  - *Fix*: Restart the OpenCode process or check `htop` for runaway agent threads.
- **Filebeat "No Data"**: Filebeat service is down or cannot reach Logstash on `.105:5044`.
  - *Fix*: `systemctl restart filebeat` and verify network connectivity to Logstash.
- **Disk Full**: Log directory has ballooned due to heavy diagnostic output.
  - *Fix*: Run the manual cleanup command in Section 3.

## 6. Anti-Patterns
- **NO direct manual configuration** of agent models: Always use the `opencode.json` configuration file.
- **NO disabling Filebeat**: All agent actions must be auditable in the central Grafana dashboard via ELK.
- **NO running heavy builds without Bazel**: Use the remote execution or local Bazel cache to prevent disk IO wait.

## 7. Governance
- **Style**: Google3 Monorepo
- **Ownership**: Development & AI Tools Team
- **Security**: The VM is isolated from the physical LAN; all access is via authorized SSH keys.
