# -----------------------------------------------------------------------------
# Alert Rule Definitions (data-driven)
# -----------------------------------------------------------------------------

locals {
  # Elasticsearch-based alert rules (3 data blocks: query → reduce → threshold)
  # Model uses metrics/bucketAggs/timeField format required by Grafana ES alerting backend.
  es_alert_rules = {
    # Group: homelab_logs
    "high-error-rate" = {
      group        = "homelab_logs"
      query        = "_exists_:error_classification AND error_severity:(critical OR high OR medium)"
      from         = 600
      threshold    = 500
      condition    = "gt"
      severity     = "warning"
      for_duration = "5m"
      group_by     = []
      summary      = "High error rate detected"
      description  = "Error count exceeded threshold (>500) in the last 10 minutes"
    }
    "critical-error-spike" = {
      group        = "homelab_logs"
      query        = "error_severity:critical"
      from         = 60
      threshold    = 5
      condition    = "gt"
      severity     = "critical"
      for_duration = "1m"
      group_by     = []
      summary      = "Critical error spike"
      description  = "More than 5 critical errors in 1 minute"
    }
    "gateway-errors" = {
      group        = "homelab_logs"
      query        = "error_classification:GATEWAY_ERROR"
      from         = 300
      threshold    = 10
      condition    = "gt"
      severity     = "warning"
      for_duration = "2m"
      group_by     = []
      summary      = "Gateway errors (502/503)"
      description  = "More than 10 gateway errors in 5 minutes"
    }
    "client-errors-spike" = {
      group        = "homelab_logs"
      query        = "host_name:traefik AND message:(400 OR 401 OR 403 OR 404 OR 405 OR 429)"
      from         = 300
      threshold    = 200
      condition    = "gt"
      severity     = "warning"
      for_duration = "5m"
      group_by     = []
      summary      = "Client errors spike (4xx)"
      description  = "More than 200 client errors (4xx) in 5 minutes"
    }
    "host-silent" = {
      group        = "homelab_logs"
      query        = "host_name:(traefik OR grafana OR elk OR glitchtip OR mcphub OR runner OR supabase OR archon OR oc OR ollama OR coredns OR youtube)"
      from         = 900
      threshold    = 5
      condition    = "lt"
      severity     = "warning"
      for_duration = "10m"
      group_by     = ["host_name.keyword"]
      summary      = "Host silent"
      description  = "Host {{ $labels.host_name_keyword }} has fewer than 5 log entries in 15 minutes"
    }
    # Group: infrastructure_health (ES rule in mixed group)
    "container-restart-loop" = {
      group        = "infrastructure_health"
      query        = "message:(\"container restart\" OR Restarting OR unhealthy OR OOMKilled) AND host:(supabase OR archon OR mcphub OR elk OR glitchtip OR grafana)"
      from         = 3600
      threshold    = 5
      condition    = "gt"
      severity     = "warning"
      for_duration = "5m"
      group_by     = []
      summary      = "Container restart loop"
      description  = "More than 5 container restart events in 1 hour on {{ $labels.host }}"
    }
    # Group: mcp_alerts
    "mcp-error-logs" = {
      group        = "mcp_alerts"
      query        = "(service:mcp OR service:mcphub OR job:mcp) AND _exists_:error_classification AND NOT error_severity:low"
      from         = 600
      threshold    = 5
      condition    = "gt"
      severity     = "warning"
      for_duration = "1m"
      group_by     = []
      summary      = "MCP error logs"
      description  = "More than 5 MCP error events in 10 minutes"
    }
    "service-log-gap" = {
      group        = "homelab_logs"
      query        = "fields.service:(traefik OR grafana OR elk OR glitchtip OR supabase OR archon OR mcphub OR runner OR opencode OR ollama OR coredns OR youtube)"
      from         = 3600
      threshold    = 1
      condition    = "lt"
      severity     = "warning"
      for_duration = "10m"
      group_by     = []
      summary      = "Service log collection gap detected"
      description  = "Service has sent fewer than 1 log events in the past 60 minutes — filebeat may be down or misconfigured"
    }
  }

  # Prometheus-based alert rules (2 data blocks: expr → threshold)
  prometheus_alert_rules = {
    # All in group: infrastructure_health
    "service-down" = {
      group        = "infrastructure_health"
      expr         = "probe_success{instance!~\".*:80\"} == 0"
      from         = 300
      threshold    = 0
      condition    = "gt"
      severity     = "critical"
      for_duration = "2m"
      summary      = "Service down"
      description  = "Blackbox probe failed for {{ $labels.instance }}"
    }
    "disk-usage-high" = {
      group        = "infrastructure_health"
      expr         = "(1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 > 80"
      from         = 300
      threshold    = 0
      condition    = "gt"
      severity     = "warning"
      for_duration = "5m"
      summary      = "Disk usage high"
      description  = "Disk usage above 80% on {{ $labels.instance }}"
    }
    "disk-usage-critical" = {
      group        = "infrastructure_health"
      expr         = "(1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 > 90"
      from         = 300
      threshold    = 0
      condition    = "gt"
      severity     = "critical"
      for_duration = "5m"
      summary      = "Disk usage critical"
      description  = "Disk usage above 90% on {{ $labels.instance }}"
    }
    "memory-pressure" = {
      group        = "infrastructure_health"
      expr         = "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100"
      from         = 300
      threshold    = 85
      condition    = "gt"
      severity     = "warning"
      for_duration = "5m"
      summary      = "Memory pressure"
      description  = "Memory usage above 85% on {{ $labels.instance }}"
    }
    "cpu-usage-high" = {
      group        = "infrastructure_health"
      expr         = "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
      from         = 600
      threshold    = 90
      condition    = "gt"
      severity     = "warning"
      for_duration = "10m"
      summary      = "CPU usage high"
      description  = "CPU usage above 90% on {{ $labels.instance }} for 10 minutes"
    }
    "container-memory-high" = {
      group        = "infrastructure_health"
      expr         = "container_memory_usage_bytes{name!=\"\"} / container_spec_memory_limit_bytes{name!=\"\"} > 0.9"
      from         = 300
      threshold    = 0
      condition    = "gt"
      severity     = "warning"
      for_duration = "5m"
      summary      = "Container {{ $labels.name }} memory > 90%"
      description  = "Container {{ $labels.name }} memory usage is above 90%"
    }
    "container-cpu-high" = {
      group        = "infrastructure_health"
      expr         = "rate(container_cpu_usage_seconds_total{name!=\"\"}[5m]) > 0.9"
      from         = 300
      threshold    = 0
      condition    = "gt"
      severity     = "warning"
      for_duration = "5m"
      summary      = "Container {{ $labels.name }} CPU > 90%"
      description  = "Container {{ $labels.name }} CPU usage is above 90%"
    }
    "container-restart-frequent" = {
      group        = "infrastructure_health"
      expr         = "increase(container_restart_count{name!=\"\"}[1h]) > 3"
      from         = 3600
      threshold    = 0
      condition    = "gt"
      severity     = "critical"
      for_duration = "0s"
      summary      = "Container {{ $labels.name }} restarted 3+ times in 1h"
      description  = "Container {{ $labels.name }} restarted more than 3 times in 1 hour"
    }
    "prometheus-target-down" = {
      group        = "infrastructure_health"
      expr         = "up == 0"
      from         = 300
      threshold    = 0
      condition    = "gt"
      severity     = "critical"
      for_duration = "3m"
      summary      = "Prometheus target down"
      description  = "Prometheus scrape target {{ $labels.instance }} (job={{ $labels.job }}) is down"
    }
    "node-load-high" = {
      group        = "infrastructure_health"
      expr         = "node_load15 / count without(cpu, mode) (node_cpu_seconds_total{mode=\"idle\"}) > 2"
      from         = 900
      threshold    = 0
      condition    = "gt"
      severity     = "warning"
      for_duration = "15m"
      summary      = "Node load high"
      description  = "15-min load average is over 2x CPU count on {{ $labels.instance }}"
    }
    "logstash-collection-stop" = {
      group        = "infrastructure_health"
      expr         = "sum(rate(logstash_events_in_total[5m]))"
      from         = 600
      threshold    = 0.001
      condition    = "lt"
      severity     = "critical"
      for_duration = "10m"
      summary      = "Log collection stopped"
      description  = "Logstash has received zero events for 10 minutes — filebeat or pipeline may be down"
    }
    "ssl-cert-expiry-warning" = {
      group        = "infrastructure_health"
      expr         = "(probe_ssl_earliest_cert_expiry - time()) / 86400"
      from         = 3600
      threshold    = 14
      condition    = "lt"
      severity     = "warning"
      for_duration = "1h"
      summary      = "SSL certificate expiring soon"
      description  = "SSL certificate for {{ $labels.instance }} expires in less than 14 days"
    }
    "ssl-cert-expiry-critical" = {
      group        = "infrastructure_health"
      expr         = "(probe_ssl_earliest_cert_expiry - time()) / 86400"
      from         = 3600
      threshold    = 7
      condition    = "lt"
      severity     = "critical"
      for_duration = "1h"
      summary      = "SSL certificate expiry imminent"
      description  = "SSL certificate for {{ $labels.instance }} expires in less than 7 days"
    }
    "postgres-connection-high" = {
      group        = "infrastructure_health"
      expr         = "pg_stat_activity_count / pg_settings_max_connections * 100 > 80"
      from         = 300
      threshold    = 0
      condition    = "gt"
      severity     = "warning"
      for_duration = "5m"
      summary      = "PostgreSQL connection usage high"
      description  = "PostgreSQL connection usage above 80% on {{ $labels.instance }}"
    }
    "postgres-replication-lag" = {
      group        = "infrastructure_health"
      expr         = "pg_replication_lag > 30"
      from         = 300
      threshold    = 0
      condition    = "gt"
      severity     = "warning"
      for_duration = "5m"
      summary      = "PostgreSQL replication lag high"
      description  = "PostgreSQL replication lag exceeds 30 seconds on {{ $labels.instance }}"
    }
    "redis-memory-high" = {
      group        = "infrastructure_health"
      expr         = "redis_memory_used_bytes / redis_memory_max_bytes * 100 > 80"
      from         = 300
      threshold    = 0
      condition    = "gt"
      severity     = "warning"
      for_duration = "5m"
      summary      = "Redis memory usage high"
      description  = "Redis memory usage above 80% on {{ $labels.instance }}"
    }
    "postgres-deadlocks" = {
      group        = "infrastructure_health"
      expr         = "rate(pg_stat_database_deadlocks_total[5m]) > 0"
      from         = 300
      threshold    = 0
      condition    = "gt"
      severity     = "warning"
      for_duration = "0s"
      summary      = "PostgreSQL deadlocks detected"
      description  = "Deadlocks detected on {{ $labels.instance }} database {{ $labels.datname }}"
    }
  }

  # Group filters
  homelab_logs_es   = { for k, v in local.es_alert_rules : k => v if v.group == "homelab_logs" }
  infra_health_es   = { for k, v in local.es_alert_rules : k => v if v.group == "infrastructure_health" }
  infra_health_prom = { for k, v in local.prometheus_alert_rules : k => v if v.group == "infrastructure_health" }
  mcp_es            = { for k, v in local.es_alert_rules : k => v if v.group == "mcp_alerts" }
}
