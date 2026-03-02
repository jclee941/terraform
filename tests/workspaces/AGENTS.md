# AGENTS: tests/workspaces - Workspace Validation Tests

## OVERVIEW
Workspace-level variable validation tests for standalone stacks (`100-pve`, `102-traefik`, `108-archon`, `109-ollama`, `300-cloudflare`, `320-slack`) using mock providers, remote state overrides, and negative assertions.

## STRUCTURE
```text
tests/workspaces/
├── archon/                     # Archon workspace remote-state tests
├── cloudflare/                 # Cloudflare workspace validation tests
├── elk/                        # ELK workspace validation tests
├── grafana/                    # Grafana workspace validation tests
├── ollama/                     # Ollama workspace remote-state + output tests
├── pve/                        # Proxmox workspace validation tests
├── slack/                      # Slack workspace validation tests
├── traefik/                    # Traefik workspace remote-state tests
├── BUILD.bazel
└── OWNERS
```

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Cloudflare workspace validation | `cloudflare/cloudflare_test.tftest.hcl` | Input format/range checks with `expect_failures`. |
| PVE workspace validation | `pve/pve_test.tftest.hcl` | Endpoint/token/node/network/VMID range/SSH key validation with `override_module` for secrets. |
| Slack workspace validation | `slack/slack_test.tftest.hcl` | Bot token format validation with `expect_failures`. |
| ELK workspace validation | `elk/elk_test.tftest.hcl` | Data view and index pattern validation with mock ES provider. |
| Grafana workspace validation | `grafana/grafana_test.tftest.hcl` | Dashboard and alert rule plan validation with mock Grafana provider. |
| Traefik workspace validation | `traefik/traefik_test.tftest.hcl` | Remote-state consumption plan test (no providers). |
| Archon workspace validation | `archon/archon_test.tftest.hcl` | Remote-state consumption plan test (no providers). |
| Ollama workspace validation | `ollama/ollama_test.tftest.hcl` | Remote-state consumption + `host_inventory_loaded` output assertion. |

## CONVENTIONS
- Keep all tests `plan`-only and provider-mocked.
- Keep each invalid input case isolated to one validation target.
- Keep override data explicit for remote state and data-source dependencies.

## ANTI-PATTERNS
- Do not introduce live API dependencies in workspace validation tests.
- Do not rely on broad assertions when exact `expect_failures` targets are available.

## COMMANDS
```bash
make test-workspace
cd tests/workspaces/pve && terraform init -backend=false && terraform test
cd tests/workspaces/cloudflare && terraform test -filter=cloudflare_test.tftest.hcl
cd tests/workspaces/slack && terraform test -filter=slack_test.tftest.hcl
```
