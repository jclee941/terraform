# AGENTS: .github/workflows

## OVERVIEW
Workflow definitions for CI, PR checks, security scans, issue automation, release automation, and shared reusable wrappers.

## STRUCTURE
```text
workflows/
├── ci.yml                         # CI wrapper
├── pr-checks.yml                  # PR gate wrapper
├── reusable-pr-checks.yml         # Local reusable PR policy checks
├── reusable-docs-sync.yml         # Local reusable docs sync/checks
├── reusable-issue-management.yml  # Local reusable issue automation
├── security/pr-review.yml         # Manual security review path
└── *.yml                          # Automation wrappers and scanners
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| CI wrapper | `ci.yml` | Delegates to `jclee941/.github/.github/workflows/reusable-ci.yml@master`. |
| PR gate wrapper | `pr-checks.yml` | Delegates to shared reusable checks. |
| Local PR policy body | `reusable-pr-checks.yml` | PR title, branch, description, size, sensitive-file checks. |
| Workflow semantic lint | `actionlint.yml` | Use this when workflow syntax or expressions change. |
| Secret scan | `gitleaks.yml` | Keep independent from normal CI. |
| Dependabot auto-merge | `dependabot-auto-merge.yml` | Patch/minor and GitHub Actions update policy. |
| Failure issue dedupe | `ci-failure-issues.yml` | Watches workflow_run failures and opens/dedupes issues. |

## CONVENTIONS
- Keep wrapper workflows small; repo-specific logic belongs in local reusable files only when shared workflows cannot own it.
- Preserve trigger scopes and path filters when editing scanners.
- Use `permissions:` blocks with least privilege for each workflow.
- Keep `concurrency:` groups stable and specific to the event/ref.
- Prefer squash auto-merge behavior for automation-created PRs.
- Keep shell blocks `bash` explicit when they depend on Bash behavior.

## ANTI-PATTERNS
- Do not add mutable action references for new dependencies.
- Do not hide real check failures behind `|| true`; existing non-fatal checks are intentional exceptions to review before changing.
- Do not run Terraform apply or production mutations from PR-triggered workflows.
- Do not pass inherited secrets to third-party reusable workflows.
- Do not remove actionlint coverage when adding workflow directories or composite actions.
