# AGENTS: tests/modules/proxmox — Proxmox Module Tests

## OVERVIEW
Unit and contract tests for `modules/proxmox/*` using Terraform test files, mocked providers, and fixture templates.

## STRUCTURE
```text
tests/modules/proxmox/
├── lxc_test.tftest.hcl              # LXC module validation and contract tests
├── vm_test.tftest.hcl               # VM module validation and contract tests
├── lxc_config_test.tftest.hcl       # LXC config template rendering checks
├── vm_config_test.tftest.hcl        # VM config template rendering checks
├── config_renderer_test.tftest.hcl  # Multi-template config renderer behavior
├── fixtures/                        # Template fixtures and expected outputs
├── main.tf                          # Test provider requirements
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| LXC and VM validation tests | `lxc_test.tftest.hcl` | VMID range, memory constraints, and pass-through assertions. |
| Template rendering module tests | `config_renderer_test.tftest.hcl` | Single/multi-template rendering and output-path assertions. |
| LXC/VM config template tests | `lxc_config_test.tftest.hcl`, `vm_config_test.tftest.hcl` | Config generation behavior checks. |
| Fixtures | `fixtures/` | Stable test templates and outputs used by renderer tests. |

## CONVENTIONS
- Keep module sources relative (`../../../modules/proxmox/<module>`).
- Use `mock_provider` and `override_data`/`override_resource` for deterministic plans.
- Add positive and negative cases together for each validation rule.
- For validation failures, target exact symbols in `expect_failures`.

## ANTI-PATTERNS
- Do not require live Proxmox endpoints for default test runs.
- Do not collapse multiple concerns into one test block; keep runs atomic.
- Do not change fixture names without updating all test references.

## COMMANDS
```bash
make test-unit
cd tests/modules/proxmox && terraform test
cd tests/modules/proxmox && terraform test -filter=lxc_test.tftest.hcl
cd tests/modules/proxmox && terraform test -filter=config_renderer_test.tftest.hcl
```
