# AGENTS: 101-runner/scripts

## OVERVIEW

Host-side runner lifecycle scripts for LXC 101. These scripts install dependencies, register per-repo runner instances, and cleanly unregister services on the runner host itself.

## STRUCTURE

```text
101-runner/scripts/
├── setup-runner.go        # Debian bootstrap: Docker, Terraform, Bazel, runner binary
├── register-all-repos.go  # Bulk registration for all owned repos and all instances
├── register-repo.go       # Single-repo registration for one or all instances
└── unregister-all.go      # Removes runner configs, services, and work dirs
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Install base dependencies | `setup-runner.go` | Creates `runner` user, installs Docker/Terraform/Bazel, sets template unit. |
| Register every repo | `register-all-repos.go` | Discovers repos from GitHub API and creates `github-runner-{N}-{repo}.service`. |
| Register one repo | `register-repo.go` | Supports all instances or a single target instance number. |
| Remove all runners safely | `unregister-all.go` | Handles both current multi-instance and legacy layouts. |

## CONVENTIONS

- Run these scripts inside LXC 101, or through `pct exec 101 -- bash` from the Proxmox host.
- Required auth is environment-based: `GITHUB_TOKEN` and `GITHUB_USER`; scaling uses `RUNNER_COUNT`.
- Service naming stays `github-runner-{instance}-{repo}` and runner directories stay under `/home/runner/runners/instance-{N}/{repo}/`.
- Scripts are rerun-safe by design: existing services stop/reconfigure, legacy cleanup is tolerated, and bootstrap avoids duplicate installs.

## ANTI-PATTERNS

- Do not run these scripts from arbitrary non-runner hosts.
- Do not store PATs in the script files, systemd units, or committed env files.
- Do not collapse per-repo instance isolation into shared working directories.
- Do not edit generated service units by hand; rerun the owning script instead.
