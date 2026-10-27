# ADR-015: Registry LAN Direct (Grey-Cloud) Exposure

**Status:** Accepted
**Date:** 2026-07-25

## Context

Docker pushes to `registry.jclee.me` through the Cloudflare Tunnel failed for image layers larger than ~100MB. Live testing on 2026-07-24 showed a 400MB layer push rejected with `413 Payload Too Large` in ~2s, while a 90MB layer succeeded. Cloudflare enforces a request-body size limit (100MB on the current plan) at its edge for proxied hostnames, including Tunnel-published applications. The Docker client uploads each layer as a single streaming PATCH/PUT with no client-side chunk-size control (moby#46744, docker/cli#5589), so the limit cannot be worked around from the client or registry configuration. Smaller layers also intermittently retried (`Unavailable` x12 on a few-KB image) due to a cloudflared QUIC transport issue with streamed uploads (cloudflared#1485).

ADR-003 mandates Cloudflare Tunnels for all external access because the homelab has no public IP and port-forwarding was rejected.

## Decision

1. `registry.jclee.me` becomes a **grey-cloud A record** (`cloudflare_dns_record.registry`, `proxied = false`) pointing to `var.cliproxy_ip` (192.168.50.114). The hostname is removed from `homelab_services` so no Tunnel CNAME or ingress rule is created for it.
2. A host-managed Traefik service (`traefik-registry`) on cliproxy terminates TLS for `registry.jclee.me` with a Let's Encrypt certificate issued via Cloudflare DNS-01 challenge (no inbound ports needed) and reverse-proxies to the plain-HTTP registry on the Synology NAS (`192.168.50.215:5051`).
3. The `cloudflared-homelab` connector on cliproxy is pinned to HTTP/2 transport (`TUNNEL_TRANSPORT_PROTOCOL=http2` systemd drop-in) to fix intermittent streamed-upload retries for the remaining Tunnel services.

## Alternatives Considered

1. **Keep Tunnel, force client chunking below 100MB** — not supported by the Docker client or registry config.
2. **Cloudflare Business/Enterprise plan** — raises the cap (200/500MB) but does not remove it and adds recurring cost for a single-host homelab.
3. **Public A record + router port-forward** — rejected in ADR-003; additionally requires DDNS and router automation that does not exist.
4. **LAN access via `insecure-registries`** — avoids TLS but requires per-client docker daemon config; violates "works automatically" goal.
5. **cloudflared access tcp pipe** — failed in testing (`websocket: bad handshake` against the plain-HTTP origin) and requires per-client cloudflared.

## Consequences

- `registry.jclee.me` resolves to a private LAN address; the registry is **unreachable from the WAN**. Pushes and pulls work from any LAN client with a publicly trusted certificate and no client configuration. Verified: 1.2GB layer push in 17.2s, pull roundtrip digest match.
- The previously world-readable unauthenticated registry is no longer publicly exposed — a security improvement given it has no auth configured.
- The Traefik terminator is host-managed (same model as `cloudflared-homelab`); it is not provisioned by Terraform. Documented in `docs/runbooks/network-issues.md`.
- The grey-cloud A record was created out-of-band via the CF API on 2026-07-25 and is adopted into Terraform state via an `import` block (removable after the first successful CI apply), following the pattern used for the 2026-07-23 records.
- Rollback: remove the A record / re-add the Tunnel CNAME by reverting the `300-cloudflare` changes and CI-applying.
