# AGENTS: 103-coredns/templates — CoreDNS Configuration

## OVERVIEW
CoreDNS zone templates for internal DNS resolution. Provides `jclee.me` and reverse DNS for the 192.168.50.0/24 subnet.

## STRUCTURE
```
templates/
├── Corefile.tftpl         # Main CoreDNS config
├── db.jclee.me.tftpl      # Forward zone: jclee.me
└── db.50.168.192.in-addr.arpa.tftpl  # Reverse zone
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| DNS server config | `Corefile.tftpl` | Plugins: file, forward, cache, log |
| Forward zone | `db.jclee.me.tftpl` | A/AAAA records for all hosts |
| Reverse zone | `db.50.168.192...tftpl` | PTR records for IP → hostname |

## CONVENTIONS
- Use `hosts` map for all record generation
- SOA serial: YYYYMMDDNN format
- TTL: 300s default
- Forwarder: Cloudflare (1.1.1.1, 1.0.0.1)

## ANTI-PATTERNS
- NEVER hand-edit zone files — regenerate from templates
- NEVER omit PTR records — required for reverse DNS
- NEVER use external DNS for internal services
