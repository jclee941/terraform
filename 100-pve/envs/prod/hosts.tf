# Proxmox Infrastructure Host Inventory
# Single Source of Truth for all host IPs, ports, and roles

locals {
  network = {
    subnet  = "192.168.50.0/24"
    gateway = "192.168.50.1"
    domain  = "jclee.me"
  }

  hosts = {
    pve = {
      vmid  = 100
      ip    = "192.168.50.100"
      roles = ["hypervisor"]
      ports = {}
    }

    # Removed: vault (was 101→repurposed), terraform (103),
    # minio_cache (109), n8n (110), swagger (was 112→repurposed), github_runner (113→repurposed to 101)
    # Removed: mcpdog (111) - migrated to mcphub (112)

    runner = {
      vmid  = 101
      ip    = "192.168.50.101"
      roles = ["ci", "github-runner"]
      ports = {}
    }

    traefik = {
      vmid  = 102
      ip    = "192.168.50.102"
      roles = ["proxy", "ingress"]
      ports = {
        http    = 80
        https   = 443
        traefik = 8080
      }
    }

    grafana = {
      vmid  = 104
      ip    = "192.168.50.104"
      roles = ["observability", "monitoring"]
      ports = {
        grafana    = 3000
        prometheus = 9090
      }
    }

    elk = {
      vmid  = 105
      ip    = "192.168.50.105"
      roles = ["logging", "elasticsearch", "kibana"]
      ports = {
        elasticsearch       = 9200
        es_transport        = 9300
        kibana              = 5601
        logstash_beat       = 5044
        logstash_tcp        = 5000
        logstash_api        = 9600
        logstash_prometheus = 9198
      }
    }

    glitchtip = {
      vmid  = 106
      ip    = "192.168.50.106"
      roles = ["error-tracking", "monitoring"]
      ports = {
        web      = 8000
        postgres = 5432
        redis    = 6379
      }
    }

    supabase = {
      vmid  = 107
      ip    = "192.168.50.107"
      roles = ["database", "backend-as-a-service", "auth"]
      ports = {
        studio   = 3000
        api      = 8000
        db       = 5432
        realtime = 4000
        inbucket = 9000
      }
    }

    archon = {
      vmid  = 108
      ip    = "192.168.50.108"
      roles = ["ai", "knowledge-management", "mcp"]
      ports = {
        ui     = 3737
        server = 8181
        mcp    = 8051
      }
    }

    mcphub = {
      vmid  = 112
      ip    = "192.168.50.112"
      roles = ["mcp-hub", "ai", "mcp", "gateway", "automation"]
      ports = {
        web        = 3000
        n8n        = 5678
        vault      = 8200
        proxmox    = 8055
        playwright = 8056
      }
    }

    synology = {
      vmid  = 215
      ip    = "192.168.50.215"
      roles = ["nas", "storage"]
      ports = {
        dsm = 5000
      }
    }

    staging = {
      vmid  = 220
      ip    = "192.168.50.220"
      roles = ["staging", "dev"]
      ports = {}
    }
  }
}

output "hosts" {
  description = "All infrastructure hosts with IPs and ports"
  value       = local.hosts
}
