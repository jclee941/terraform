# AGENTS: tests/modules — Module Test Parent

## OVERVIEW
Parent scope for Terraform-native module tests. Owns the boundary between reusable module contract tests here and higher-level pipeline or workspace validation elsewhere under `tests/`.

## STRUCTURE
```text
tests/modules/
├── proxmox/   # Proxmox module unit and rendering tests
├── shared/    # Shared-module contract tests
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Proxmox module tests | `proxmox/AGENTS.md` | LXC, VM, config-renderer, and config-deploy test suites. |
| Shared module tests | `shared/AGENTS.md` | onepassword-secrets provider-mock contracts. |
| Cross-module integration | `../integration/AGENTS.md` | Use when behavior spans more than one module family. |
| Workspace validation | `../workspaces/AGENTS.md` | Use for root workspace inputs and remote-state contracts. |

## CONVENTIONS
- Keep module sources relative from the test root (`../../../modules/...`).
- Keep provider behavior mocked by default; module tests should stay deterministic and offline.
- Add exact-symbol `expect_failures` targets for validation failures instead of broad assertions.
- Keep shared fixture names stable because child suites reference them directly.

## ANTI-PATTERNS
- Do not move workspace-specific validation into this branch; keep it under `tests/workspaces/`.
- Do not turn module tests into live infrastructure checks.
- Do not duplicate child-suite details here; this file owns only the parent boundary.

## COMMANDS
```bash
make test-unit
cd tests/modules/proxmox && terraform init -backend=false && terraform test
cd tests/modules/shared && terraform init -backend=false && terraform test
```
