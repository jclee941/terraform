# AGENTS: 101-runner/config — GitLab Runner Configuration

## OVERVIEW
Configuration templates and runtime configs for the GitLab Runner LXC (VMID 101). Runner executes CI/CD pipelines for all Terraform workspaces.

## STRUCTURE
```
config/
├── config.toml.tftpl      # Main runner config template
└── .gitlab/               # CI helper configs
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Runner registration | `config.toml.tftpl` | Executor, cache, concurrent jobs |
| CI helper scripts | `.gitlab/` | Shared CI utilities |

## CONVENTIONS
- Use `config.toml.tftpl` as template, rendered to `/etc/gitlab-runner/config.toml`
- Shell executor with Docker-in-Docker support
- Cache: S3-compatible (MinIO) on infra subnet

## ANTI-PATTERNS
- NEVER commit registration tokens — use 1Password
- NEVER use privileged containers in production
- NEVER hardcode URLs — use `module.hosts` references
