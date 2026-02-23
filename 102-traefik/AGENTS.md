# PROJECT KNOWLEDGE: 102-TRAEFIK

**Reason**: Critical Ingress
**Governance**: Google3 Style (Bazel)

## OVERVIEW
High-performance edge router and reverse proxy (LXC 102) for the `jclee.me` ecosystem. Acts as the solitary entry point for all subdomains, orchestrating TLS termination (Let's Encrypt/Cloudflare DNS-01), load balancing, and request-level security. Critical dependency for all user-facing services.

## STRUCTURE
- `terraform/`: Resource lifecycle and main container config.
- `templates/`: Jinja2/TF templates for dynamic route generation.
- `tf-configs/`: **Rendered SSoT**. Final YAMLs generated from `hosts.tf`.
- `config/`: Static and manually maintained dynamic file provider configs.
- `templates/cloudflared-docker-compose.yml.tftpl`: Cloudflared tunnel connector template (rendered by 100-pve pipeline).

## WHERE TO LOOK
- **Service Routing**: Check `tf-configs/traefik-{service}.yml`. Generated from central inventory.
- **Middlewares**: Primary definitions reside in `tf-configs/traefik.yml` and `config/middlewares.yml`.
- **Cert Management**: SSL state stored in `/etc/traefik/acme.json` (inside LXC 102).
- **Access Logs**: `/var/log/traefik/access.log` (monitored via Filebeat).

## CONVENTIONS
- **MCP Ingress**: MCP traffic is routed through `https://mcphub.jclee.me/mcp`.
- **Resilience**: All internal/MCP routes MUST include the `mcp-resilient` middleware chain (Retry-5 + Circuit Breaker).
- **Subdomains**: Standard format is `https://{service}.jclee.me`.
- **Backend IPs**: Never hardcode. Always inject via `module.hosts` from `100-pve/envs/prod/hosts.tf`.

## ANTI-PATTERNS
- **NO Plaintext**: Direct HTTP access is forbidden; redirect to 443 is mandatory.
- **NO Manual Mutation**: Editing files in `/etc/traefik/dynamic/` on the LXC is prohibited; use TF.
- **Token Exposure**: Never place sensitive auth headers or tokens in public `BUILD.bazel` or YAML configs.
- **Insecure Middlewares**: Routing new backends without security headers (`chain-basic-auth`) is a violation.

## COMMANDS
```bash
# Verify active routing table
ssh root@192.168.50.100 'pct exec 102 -- curl -s localhost:8080/api/http/routers | jq'

# Tail live access logs
ssh root@192.168.50.100 'pct exec 102 -- tail -f /var/log/traefik/access.log'
```
