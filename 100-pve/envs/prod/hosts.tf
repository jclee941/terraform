terraform {
  required_version = ">= 1.7, < 2.0"
}

# Proxmox Infrastructure Host Inventory
# Single Source of Truth for all host IPs, ports, and roles

locals {

  hosts = {
    jclee = {
      vmid  = 80
      ip    = "192.168.50.80"
      roles = ["workstation"]
      ports = {
        rdp = 3389
        ssh = 22
      }
    }

    pve = {
      ip    = "192.168.50.100"
      roles = ["hypervisor"]
      ports = {}
    }

    cliproxy = {
      vmid  = 100
      ip    = "192.168.50.114"
      roles = ["proxy", "squid"]
      ports = {
        proxy = 3128
      }
    }

    runner = {
      vmid  = 101
      ip    = "192.168.50.101"
      roles = ["ci", "runner", "github"]
      ports = {}
    }

    # Note: runner (101) is active - LXC container for GitHub Actions CI (migrated from HDD to SSD 2026-03-28)
    # Removed: vault (was 101->repurposed), terraform (103),
    # minio_cache (109), n8n (110), swagger (was 112->repurposed), github_runner (113->repurposed to 101)
    # Removed: mcpdog (111) - migrated to mcphub (112)

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

    coredns = {
      vmid  = 103
      ip    = "192.168.50.103"
      roles = ["dns", "split-dns"]
      ports = {
        dns    = 53
        health = 8080
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
        logstash_http       = 8080
      }
    }

    supabase = {
      vmid  = 107
      ip    = "192.168.50.107"
      roles = ["database", "backend-as-a-service", "auth"]
      ports = {
        studio            = 3000
        api               = 8000
        db                = 5432
        realtime          = 4000
        inbucket          = 9000
        postgres_exporter = 9187
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

    n8n = {
      vmid  = 110
      ip    = "192.168.50.110"
      roles = ["automation", "workflow"]
      ports = {
        n8n               = 5678
        postgres          = 5432
        cadvisor          = 8888
        postgres_exporter = 9187
      }
    }

    mcphub = {
      vmid  = 112
      ip    = "192.168.50.112"
      roles = ["mcp-hub", "ai", "mcp", "gateway", "automation"]
      ports = {
        web        = 3000
        proxmox    = 8055
        playwright = 8056
        op_connect = 8090
        cadvisor   = 8888
      }
    }

    jclee-dev = {
      vmid  = 200
      ip    = "192.168.50.200"
      roles = ["development", "workstation"]
      ports = {
        rdp      = 3389
        ssh      = 22
        opencode = 8090
      }
    }
    synology = {
      vmid  = 215
      ip    = "192.168.50.215"
      roles = ["nas", "storage"]
      ports = {
        dsm       = 5000
        dsm_https = 5001
        registry  = 5000
      }
    }

    youtube = {
      vmid  = 220
      ip    = "192.168.50.220"
      roles = ["youtube", "media"]
      ports = {
        cadvisor = 8888
      }
    }
  }
}

output "hosts" {
  description = "All infrastructure hosts with IPs and ports"
  value       = local.hosts
}
