# Network Issues: Cloudflare Tunnel, DNS, Firewall

## Symptoms

- Services reachable by IP but not by hostname
- A public hostname returns an edge error or cannot reach its direct origin
- Intermittent connectivity between containers/VMs
- Certificate errors on HTTPS endpoints

## Network Map

| VMID | IP             | Hostname  | Gateway      |
| ---- | -------------- | --------- | ------------ |
| 100  | 192.168.50.100 | pve       | 192.168.50.1 |
| 105  | 192.168.50.105 | elk       | 192.168.50.1 |
| 114  | cliproxy      | cliproxy  | 192.168.50.1 |
| 200  | 192.168.50.200 | oc        | 192.168.50.1 |
| 215  | 192.168.50.215 | synology  | 192.168.50.1 |
| 220  | 192.168.50.220 | youtube   | 192.168.50.1 |

Subnet: `192.168.50.0/24`, Gateway: `192.168.50.1`

Guest DNS uses the router at `192.168.50.1` and `8.8.8.8` as a secondary resolver. There is no internal split-DNS service. Public access uses the native `cloudflared-homelab` systemd service on cliproxy (LXC 114), which routes each hostname directly to a service IP:port.

### Public Direct Routes

| Hostname | Direct origin |
| --- | --- |
| `elk.jclee.me`, `kibana.jclee.me` | `192.168.50.105:5601` |
| `es.jclee.me` | `192.168.50.105:9200` |
| `grafana.jclee.me` | `192.168.50.215:3456` |
| `nas.jclee.me` | `https://192.168.50.215:5001` |
| `youtube.jclee.me` | `192.168.50.220:30800` |
| `idle.jclee.me` | `192.168.50.220:6080` |
| `code.jclee.me` | `192.168.50.200:8888` |
| `logstash-ingest.jclee.me` | `192.168.50.105:8080` plus TCP SSH/RDP entries |

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

### 2. Cloudflare Tunnel and Direct Origin Debug

```bash
# Check the native tunnel connector on cliproxy
pct exec 114 -- systemctl status cloudflared-homelab
pct exec 114 -- journalctl -u cloudflared-homelab --since "15 minutes ago" --no-pager

# Check direct origin reachability from cliproxy
pct exec 114 -- curl -sv http://192.168.50.105:9200/_cluster/health
pct exec 114 -- curl -sv http://192.168.50.215:5051/v2/
```

### 3. DNS Resolution

```bash
# Check PVE DNS config
ssh pve
cat /etc/resolv.conf

# Test DNS from a guest through the router
pct exec {VMID} -- cat /etc/resolv.conf
pct exec {VMID} -- nslookup elk.jclee.me 192.168.50.1
```

### 4. Service Endpoint Testing

```bash
# Test the public Cloudflare hostname
curl -v https://elk.jclee.me

# Test the direct origin from the LAN
curl -s http://192.168.50.105:9200/_cluster/health # Elasticsearch direct
```

## Resolution

### Tunnel or Direct-Origin Failure

```bash
# Check connector logs and restart the native service if needed
pct exec 114 -- journalctl -u cloudflared-homelab -n 100 --no-pager
pct exec 114 -- systemctl restart cloudflared-homelab

# Re-test the origin directly before testing the public hostname
curl -sv http://192.168.50.105:5601
```

### Container Network Reset

```bash
ssh pve
pct stop {VMID}
pct start {VMID}

# If interface is missing
pct set {VMID} -net0 name=eth0,bridge=vmbr0,ip=192.168.50.{LAST_OCTET}/24,gw=192.168.50.1
```

### Certificate or Hostname Issues

```bash
# Check the Cloudflare edge certificate and tunnel response
curl -svI https://elk.jclee.me
pct exec 114 -- journalctl -u cloudflared-homelab --since "30 minutes ago" --no-pager

# Confirm the configured origin scheme directly
curl -sv https://192.168.50.215:5001
```

## Prevention

- Tunnel ingress and DNS records are managed by the Cloudflare workspace — do not edit generated guest files.
- The `cloudflared-homelab` service runs natively on cliproxy (LXC 114).
- Keep guest resolvers pointed at router `192.168.50.1` with `8.8.8.8` as secondary DNS.
- Monitor both direct origins and public Cloudflare hostnames from the current alerting pipeline.
