# Supabase Health Check Runbook

## Scope

Troubleshooting guide for Supabase service health check failures on LXC 107.

## Host

- **Container ID**: 107
- **IP Address**: 192.168.50.107
- **Services**: Studio (3000), Kong API Gateway (8000), PostgreSQL (5432), Realtime (4000)

## Common Issues

### 1. Supabase Studio Not Responding (Port 3000)

**Symptoms**: Health check fails with status 000 or 502/503

**Diagnosis**:
```bash
pct exec 107 -- docker compose ps
pct exec 107 -- docker compose logs studio --tail=50
```

**Resolution**:
```bash
# Restart Studio service
pct exec 107 -- docker compose restart studio

# If persistent, restart all services
pct exec 107 -- docker compose restart
```

### 2. Kong API Gateway Issues (Port 8000)

**Symptoms**: Kong returns 404 or no response

**Diagnosis**:
```bash
pct exec 107 -- docker compose logs kong --tail=50
```

**Resolution**:
```bash
# Restart Kong
pct exec 107 -- docker compose restart kong

# Verify Kong database migrations
pct exec 107 -- docker compose exec kong kong migrations list
```

### 3. PostgreSQL Connection Issues (Port 5432)

**Symptoms**: Database not listening, connection refused

**Diagnosis**:
```bash
pct exec 107 -- docker compose logs db --tail=50
pct exec 107 -- docker compose exec db pg_isready -U supabase_admin
```

**Resolution**:
```bash
# Restart database
pct exec 107 -- docker compose restart db

# Check disk space
pct exec 107 -- df -h

# Check memory usage
pct exec 107 -- free -h
```

### 4. Realtime Service Issues (Port 4000)

**Symptoms**: WebSocket connections failing

**Diagnosis**:
```bash
pct exec 107 -- docker compose logs realtime --tail=50
```

**Resolution**:
```bash
pct exec 107 -- docker compose restart realtime
```

## Full Recovery Procedures

### Soft Recovery (Restart Services)

```bash
# Enter container
pct exec 107 -- bash

# Restart all Supabase services
docker compose restart

# Wait for services to be healthy
docker compose ps
```

### Hard Recovery (Full Container Restart)

```bash
# Stop container
pct stop 107

# Wait for clean shutdown
sleep 10

# Start container
pct start 107

# Wait for services
sleep 30
pct exec 107 -- docker compose ps
```

## Verification Commands

```bash
# Check all services are running
pct exec 107 -- docker compose ps

# Test Studio
curl -s -o /dev/null -w "%{http_code}" http://192.168.50.107:3000

# Test Kong
curl -s -o /dev/null -w "%{http_code}" http://192.168.50.107:8000

# Test PostgreSQL
nc -z 192.168.50.107 5432 && echo "PostgreSQL is listening"

# Test Realtime
curl -s http://192.168.50.107:4000/socket
```

## Monitoring

- Health check runs every 6 hours
- Failed checks create GitHub issues automatically
- Container metrics available in Grafana dashboard

## References

- Supabase Docker Compose: `/opt/supabase/docker-compose.yml` (inside LXC 107)
- Supabase documentation: https://supabase.com/docs
- Infrastructure code: `107-supabase/` in this repository
