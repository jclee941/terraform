# AGENTS: .github

## OVERVIEW
GitHub repository automation boundary: PR gates, CI wrappers, issue automation, security scans, templates, and CODEOWNERS. Dependabot was retired in #620.

## STRUCTURE
```text
.github/
├── workflows/         # CI, AI/security review, release automation
├── actions/           # Composite actions (build cache, Python setup)
├── workflow-registry.yml  # Workflow catalog audited by scripts/audit-workflows.go
├── ISSUE_TEMPLATE/    # Bug/feature/security issue forms
├── CODEOWNERS
└── PULL_REQUEST_TEMPLATE.md
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Main CI entry | `workflows/ci.yml` | Local secretless validation with SHA-pinned actions. |
| Workflow inventory | `workflow-registry.yml` | Update with every workflow add/rename; `go run scripts/audit-workflows.go` fails on drift. |
| AI/security review | `workflows/10_pr-review.yml` + `workflows/11_security-pr-review.yml` | AI code review and security audit on PRs. |
| Releases | `workflows/24_release-notes.yml` + `workflows/25_release-publish.yml` | Release notes and semver release publishing. |
| Secret scan / workflow lint | `.pre-commit-config.yaml` | gitleaks and actionlint run as pre-commit hooks; no dedicated workflow. |
| Repo policy text | `PULL_REQUEST_TEMPLATE.md`, `CODEOWNERS` | Review routing policy. |

## CONVENTIONS
- Keep the main CI validation local, secretless, and free of production mutation paths.
- Use `self-hosted` for private-repo jobs when workflows already follow that visibility split.
- Keep concurrency groups per workflow/ref or PR number to avoid duplicate automation.
- Preserve `secrets: inherit` only for trusted reusable workflow calls.
- When adding actions, SHA-pin with a version comment if possible; existing files still contain mixed tag pinning.
- Master has no required status checks (ruleset keeps deletion and non-fast-forward protection only); PRs are merged manually and repository auto-merge is disabled.

## ANTI-PATTERNS
- Do not enable local deploy/apply flows here; Terraform applies are CI/CD controlled.
- Do not add workflows that expose `.tfvars`, `.env`, state, or generated secret-bearing `data/` files.
- Do not silently replace shared reusable workflow calls with local copies unless the shared contract changed.
- Do not use production secrets in PR-triggered jobs from untrusted forks.
- Do not weaken actionlint/gitleaks gates when fixing workflow syntax.
