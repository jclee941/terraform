# AGENTS: 101-runner/templates — GitHub Actions Runner Templates

## OVERVIEW
Terraform templates for GitHub Actions runner service configuration. Rendered by `100-pve` into runner-specific configs.

## STRUCTURE
```
templates/
└── filebeat.yml.tftpl     # Runner log shipping template
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Filebeat config | `filebeat.yml.tftpl` | Runner log shipping into Logstash |

## CONVENTIONS
- Use `templatefile()` in `100-pve` to render
- Pass variables via `templatefile(path, { var1 = val1, ... })`
- Use `module.hosts` for service URLs

## ANTI-PATTERNS
- NEVER hardcode secrets — use `${var.secret}` placeholders
- NEVER use absolute paths — template renders to guest paths

## NOTES
- Keep this template aligned with `101-runner/config/filebeat.yml`.
- Runner registration scripts live in `../scripts/`, not this template directory.
- Use `make plan SVC=pve` to inspect rendered config changes.
