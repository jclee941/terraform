# AGENTS: tests/integration - Pipeline Integration Tests

## OVERVIEW
Cross-module tests validating real rendering behavior for the config pipeline and hosts-map substitution patterns.

## WHERE TO LOOK
| Task | File | Notes |
|------|------|-------|
| Config renderer integration | `config_pipeline_test.tftest.hcl` | End-to-end template rendering assertions with realistic host maps. |
| Integration fixtures | `fixtures/` | Template inputs used by integration runs. |

## CONVENTIONS
- Keep integration runs focused on inter-module behavior, not single-module contract details.
- Use realistic host/port maps so rendered outputs match production shape.
- Assert unresolved template variables are absent in rendered output.

## ANTI-PATTERNS
- Do not replace integration checks with pure mock assertions already covered by unit tests.
- Do not treat fixture outputs as source of truth for template logic.
