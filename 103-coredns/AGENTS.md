# AGENTS: 103-coredns

## OVERVIEW

Split DNS resolver on LXC 103 (192.168.50.103, 256MB RAM, 1 core, 4GB disk). CoreDNS resolves `*.jclee.me` to Traefik (192.168.50.102) for internal clients, bypassing Cloudflare Tunnel. All other queries forwarded upstream.

## WHERE TO LOOK

| Task             | Location                             | Notes                                    |
| ---------------- | ------------------------------------ | ---------------------------------------- |
| CoreDNS config   | `templates/Corefile.tftpl`           | Zone definitions and upstream forwarders |
| Docker compose   | `templates/docker-compose.yml.tftpl` | Container runtime config                 |
| Filebeat config  | `templates/filebeat.yml.tftpl`       | Log collection agent                     |
| Rendered outputs | `100-pve/configs/rendered/coredns/`  | Generated — do not edit                  |

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
