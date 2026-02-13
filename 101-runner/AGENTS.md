# PROJECT KNOWLEDGE BASE: 101-RUNNER

**Updated:** 2026-02-13
**Target:** LXC 101 (Debian 12)
**IP:** 192.168.50.101

## OVERVIEW
Dedicated GitHub Actions self-hosted runner infrastructure for the `qws941` user. Orchestrates registration across 8+ repositories (blacklist, claude, propose, proxmox, resume, safework2, splunk, terraform) using JIT-config. Provides direct access to homelab services (Proxmox, Vault, ELK) for integration testing and automated deployments. Includes Terraform and Bazel for infrastructure CI/CD.

## STRUCTURE
```
101-runner/
├── BUILD.bazel          # Monorepo integration (all_configs)
├── OWNERS               # Access control (Infrastructure)
├── README.md            # Hardware/Setup documentation
├── config/
│   └── filebeat.yml     # Log forwarding to ELK (105)
├── templates/
│   └── filebeat.yml.tftpl  # Templated filebeat config
└── scripts/             # Runner lifecycle management
    ├── setup-runner.sh       # Dependency bootstrap, Docker, Terraform, Bazel
    ├── register-all-repos.sh # SSoT for multi-repo registration
    ├── register-repo.sh      # Single repo registration handler
    └── unregister-all.sh     # Safe cleanup and token revocation
```

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| **Add new repo** | `scripts/register-all-repos.sh` | Add repo to `REPOS` list |
| **Troubleshoot logs**| `config/filebeat.yml` | Verified against Logstash:5044 |
| **Base dependencies**| `scripts/setup-runner.sh` | Python, Docker, Terraform, Bazel |
| **Service Control** | `README.md` | systemd templates: `github-runner@<repo>` |

## CONVENTIONS
- **Governance**: Managed by Terraform (`module.lxc["runner"]`). VMID 101 is fixed.
- **Isolation**: Each repository gets a dedicated systemd service and working directory (`/home/runner/runners/<repo>`).
- **Labels**: Jobs MUST use `runs-on: [self-hosted, homelab]` to target this runner.
- **Networking**: Unprivileged LXC with `nesting=1` enabled for Docker-in-Docker support.
- **Naming**: Follows `{VMID}-{HOSTNAME}` (101-runner) for Proxmox and GitHub identifiers.

## ANTI-PATTERNS
- **NO manual config** inside LXC. Use scripts or Terraform remote-exec.
- **NO shared state** between repos. Each runner instance is independent.
- **NO plaintext tokens**. Use environment variables or Vault integration.
- **NO direct SSH**. Use `ssh root@pve 'pct exec 101 -- bash'` from PVE host.
- **NO persistent storage** in work dirs. Cleaned by `unregister-all.sh`.
