# AGENTS: 101-runner/templates — GitLab Runner Templates

## OVERVIEW
Terraform templates for GitLab Runner service configuration. Rendered by `100-pve` into runner-specific configs.

## STRUCTURE
```
templates/
└── config.toml.tftpl      # Runner configuration template
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Runner config | `config.toml.tftpl` | Executor, tags, cache, concurrent jobs |

## CONVENTIONS
- Use `templatefile()` in `100-pve` to render
- Pass variables via `templatefile(path, { var1 = val1, ... })`
- Use `module.hosts` for service URLs

## ANTI-PATTERNS
- NEVER hardcode secrets — use `${var.secret}` placeholders
- NEVER use absolute paths — template renders to guest paths
