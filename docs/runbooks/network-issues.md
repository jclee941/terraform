# Network Issues: Traefik, DNS, Firewall

## Symptoms
- Services reachable by IP but not by hostname
- Traefik returning 404 or 502 for specific routes
- Intermittent connectivity between containers/VMs
- Certificate errors on HTTPS endpoints

## Network Map

| VMID | IP | Hostname | Gateway |
|------|----|----------|---------|
| 100 | 192.168.50.100 | pve | 192.168.50.1 |
| 101 | 192.168.50.101 | runner | 192.168.50.1 |
| 102 | 192.168.50.102 | traefik | 192.168.50.1 |
| 104 | 192.168.50.104 | grafana | 192.168.50.1 |
| 105 | 192.168.50.105 | elk | 192.168.50.1 |
| 106 | 192.168.50.106 | glitchtip | 192.168.50.1 |
| 112 | 192.168.50.112 | mcphub | 192.168.50.1 |
| 200 | 192.168.50.200 | oc | 192.168.50.1 |

Subnet: `192.168.50.0/24`, Gateway: `192.168.50.1`

## Diagnosis

### 1. Basic Connectivity
```bash
# From PVE host, ping target
ssh pve
ping -c 3 192.168.50.{VMID}

# Check if container network is up
pct exec {VMID} -- ip addr show
pct exec {VMID} -- ping -c 3 192.168.50.1  # Test gateway
```

### 2. Traefik Routing Debug
```bash
# Check Traefik dashboard
curl -s http://192.168.50.102:8080/api/http/routers | jq '.[].rule'

# Check Traefik logs for routing errors
pct exec 102 -- docker logs traefik --tail 50 2>&1 | grep -i error

# Verify dynamic routing configs
pct exec 102 -- ls /etc/traefik/config/
# Files: elk.yml, glitchtip.yml, mcp.yml, vault.yml, mcphub.yml
```

### 3. DNS Resolution
```bash
# Check PVE DNS config
ssh pve
cat /etc/resolv.conf

# Test DNS from container
pct exec {VMID} -- nslookup grafana.jclee.me
```

### 4. Service Endpoint Testing
```bash
# Test each service endpoint through Traefik
curl -v https://grafana.jclee.me/api/health
curl -v https://elk.jclee.me
curl -v https://glitchtip.jclee.me/healthz
curl -v https://mcphub.jclee.me
curl -v https://vault.jclee.me

# Test direct (bypass Traefik)
curl -s http://192.168.50.104:3000/api/health  # Grafana direct
curl -s http://192.168.50.105:9200              # Elasticsearch direct
```

## Resolution

### Traefik Route Mismatch
```bash
# Check dynamic routing config
pct exec 102 -- cat /etc/traefik/config/{service}.yml

# Restart Traefik to reload configs
pct exec 102 -- docker restart traefik
```

### Container Network Reset
```bash
ssh pve
pct stop {VMID}
pct start {VMID}

# If interface is missing
pct set {VMID} -net0 name=eth0,bridge=vmbr0,ip=192.168.50.{LAST_OCTET}/24,gw=192.168.50.1
```

### Certificate Issues
```bash
# Traefik uses Let's Encrypt via ACME
# Check cert status
pct exec 102 -- docker exec traefik cat /letsencrypt/acme.json | jq '.Certificates[].domain'

# Force cert renewal
pct exec 102 -- docker restart traefik
```

## Prevention
- Traefik routing configs managed by Terraform — do NOT edit manually on LXC 102
- All routing files in `102-traefik/config/` (elk.yml, glitchtip.yml, mcp.yml, vault.yml, mcphub.yml)
- DNS records managed in Cloudflare
- Monitor with blackbox exporter in Grafana (SLA dashboard)
