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

    # pbs = {
    #   vmid  = 250
    #   ip    = "192.168.50.250"
    #   roles = ["backup", "pbs"]
    #   ports = {
    #     api = 8007
    #   }
    # }


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

    cliproxy = {
      vmid  = 114
      ip    = "192.168.50.114"
      roles = ["proxy", "cli", "api"]
      ports = {
        ssh = 22
        web = 3000
        api = 8317
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
