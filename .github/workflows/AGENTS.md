# AGENTS: .github/workflows

## OVERVIEW
Workflow definitions for CI, PR checks, security scans, issue automation, release automation, and shared reusable wrappers.

## STRUCTURE
```text
workflows/
├── ci.yml                         # Local secretless validation
├── 10_pr-review.yml               # AI code review
├── 11_security-pr-review.yml      # Security audit
├── 24_release-notes.yml           # Release notes
└── 25_release-publish.yml         # Semver release publish
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Main CI | `ci.yml` | Runs local formatting, validation, Terraform tests, Go tests, and docs checks. |
| Workflow inventory | `../workflow-registry.yml` | Keep in sync; `go run scripts/audit-workflows.go` exits 1 on drift. |
| AI/security review | `10_pr-review.yml`, `11_security-pr-review.yml` | PR review via CLIProxyAPI and security audit. |
| Releases | `24_release-notes.yml`, `25_release-publish.yml` | Release notes and semver publishing. |
| Workflow lint / secret scan | `../../.pre-commit-config.yaml` | actionlint and gitleaks run as pre-commit hooks. |

## CONVENTIONS
- Keep `ci.yml` local, secretless, SHA-pinned, and limited to non-mutating validation.
- Preserve trigger scopes and path filters when editing scanners.
- Use `permissions:` blocks with least privilege for each workflow.
- Keep `concurrency:` groups stable and specific to the event/ref.
- Open and merge PRs manually (squash); repository auto-merge is disabled and no workflow enables it.
- Keep shell blocks `bash` explicit when they depend on Bash behavior.

## ANTI-PATTERNS
- Do not add mutable action references for new dependencies.
- Do not hide real check failures behind `|| true`; existing non-fatal checks are intentional exceptions to review before changing.
- Do not run Terraform apply or production mutations from PR-triggered workflows.
- Do not pass inherited secrets to third-party reusable workflows.
- Do not remove actionlint coverage when adding workflow directories or composite actions.
