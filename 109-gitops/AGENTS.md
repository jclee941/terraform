# AGENTS: 109-gitops

> **Host**: LXC 109 | **IP**: 192.168.50.109 | **Status**: Terraform-managed controller

## OVERVIEW

Dedicated GitOps controller host for the homelab. This LXC runs a lightweight
open-source `gitops-agent` container that pulls the `qws941/terraform`
repository, tracks the last dispatched commit, resolves safe workspace targets
via `scripts/gitops-targets`, and dispatches the existing
`gitops-reconcile.yml` workflow through the GitHub Actions API.

## STRUCTURE

```text
109-gitops/
├── AGENTS.md
├── README.md
└── templates/
    ├── .env.tftpl
    ├── Dockerfile.tftpl
    ├── docker-compose.yml.tftpl
    └── filebeat.yml.tftpl
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Controller runtime env | `templates/.env.tftpl` | GitHub token, branch, repo, poll interval |
| Container image build | `templates/Dockerfile.tftpl` | Builds `gitops-agent` into the runtime image |
| Compose stack | `templates/docker-compose.yml.tftpl` | Single long-running controller service |
| Log shipping | `templates/filebeat.yml.tftpl` | Docker + system log forwarding to ELK |

## CONVENTIONS

- Lifecycle is owned by `100-pve`; this directory only defines runtime files.
- The controller dispatches GitHub workflows; it does not run Tier-0 Terraform
  applies locally.
- Keep the service headless; inbound firewall remains SSH-only unless a future
  UI or metrics endpoint is added intentionally.

## ANTI-PATTERNS

- Do not hardcode GitHub PATs or repository URLs outside templates.
- Do not let this host auto-dispatch `100-pve` applies.
- Do not replace `scripts/gitops-targets` routing logic here; consume it.
