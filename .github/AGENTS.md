# AGENTS: .github

## OVERVIEW
GitHub repository automation boundary: PR gates, CI wrappers, issue automation, security scans, templates, CODEOWNERS, and Dependabot.

## STRUCTURE
```text
.github/
├── workflows/         # CI, PR gates, automation, security, reusable workflow wrappers
├── ISSUE_TEMPLATE/    # Bug/feature/security issue forms
├── CODEOWNERS
├── PULL_REQUEST_TEMPLATE.md
└── dependabot.yml
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Main CI entry | `workflows/ci.yml` | Wrapper around `jclee941/.github/.github/workflows/reusable-ci.yml@master`. |
| PR metadata gates | `workflows/pr-checks.yml` + `workflows/reusable-pr-checks.yml` | Title, branch, description, size, sensitive-file checks. |
| Workflow linting | `workflows/actionlint.yml` | Downloads actionlint tarball and verifies SHA256. |
| Secret scanning | `workflows/gitleaks.yml` | Independent PR/push gate. |
| AI/code review | `workflows/pr-review.yml` + `workflows/security/pr-review.yml` | Separate normal and manual security review paths. |
| Shared automation wrappers | `workflows/{auto-merge,docs-sync,issue-management,welcome,labeler}.yml` | Many call reusable workflows in `jclee941/.github`. |
| Repo policy text | `PULL_REQUEST_TEMPLATE.md`, `CODEOWNERS`, `dependabot.yml` | Review routing and update policy. |

## CONVENTIONS
- Prefer local workflow files only for repo-specific policy; shared behavior usually belongs in `jclee941/.github`.
- Use `self-hosted` for private-repo jobs when workflows already follow that visibility split.
- Keep concurrency groups per workflow/ref or PR number to avoid duplicate automation.
- Preserve `secrets: inherit` only for trusted reusable workflow calls.
- When adding actions, SHA-pin with a version comment if possible; existing files still contain mixed tag pinning.
- Keep PR status contexts stable; branch protection depends on the reusable PR-check job names.

## ANTI-PATTERNS
- Do not enable local deploy/apply flows here; Terraform applies are CI/CD controlled.
- Do not add workflows that expose `.tfvars`, `.env`, state, or generated secret-bearing `data/` files.
- Do not silently replace shared reusable workflow calls with local copies unless the shared contract changed.
- Do not use production secrets in PR-triggered jobs from untrusted forks.
- Do not weaken actionlint/gitleaks gates when fixing workflow syntax.
