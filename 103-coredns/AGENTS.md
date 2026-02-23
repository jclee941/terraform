# 103-coredns

**Generated:** 2026-02-23
**Commit:** b6e4683
**Branch:** master

## OVERVIEW

Split DNS resolver on LXC 103. CoreDNS resolves `*.jclee.me` to Traefik (192.168.50.102) for internal clients, bypassing Cloudflare Tunnel. All other queries forwarded upstream.

## IDENTITY

- **VMID:** 103
- **IP:** 192.168.50.103
- **Role:** Internal DNS resolver (split-horizon)
- **Specs:** 256MB RAM, 256MB swap, 1 core, 4GB disk

## STRUCTURE

```text
103-coredns/
├── AGENTS.md
├── BUILD.bazel
├── OWNERS
├── README.md
└── templates/
    ├── BUILD.bazel
    ├── OWNERS
    ├── Corefile.tftpl
    ├── docker-compose.yml.tftpl
    └── filebeat.yml.tftpl
```

## CONVENTIONS

- CoreDNS runs as Docker container on host network.
- Corefile resolves `jclee.me` zone to Traefik IP; all else forwarded to 1.1.1.1 / 8.8.8.8.
- Config rendered via `config_renderer` pipeline (same as all other services).
- Filebeat agent deployed for log collection.

## ANTI-PATTERNS

- Never manually edit rendered configs under `100-pve/configs/rendered/coredns/`.
- Never point external DNS clients at this resolver (internal-only).

## NOTES

- DHCP/router DNS setting must be changed to 192.168.50.103 for internal auto-resolution.
- This is a blocked manual step outside IaC scope.
