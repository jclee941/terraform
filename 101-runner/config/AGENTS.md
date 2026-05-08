# AGENTS: 101-runner/config — GitHub Actions Runner Configuration

## OVERVIEW
Configuration assets for the GitHub Actions self-hosted runner LXC (VMID 101). Runner executes CI/CD workflows for all Terraform workspaces.

## STRUCTURE
```
config/
└── filebeat.yml          # Log forwarding to ELK (105)
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Filebeat shipping | `filebeat.yml` | Forwards `/var/log/*` to Logstash:5044 |

## CONVENTIONS
- Templates rendered by Terraform (`100-pve` workspace) into the LXC.
- Runner registration handled by `scripts/register-all-repos.go` (no static config.toml).
- Cache: NFS bind mount at `/srv/runner/cache`.

## ANTI-PATTERNS
- NEVER commit registration tokens — use 1Password.
- NEVER use privileged containers in production.
- NEVER hardcode URLs — use `module.hosts` references.
