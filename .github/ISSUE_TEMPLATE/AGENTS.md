# AGENTS: .github/ISSUE_TEMPLATE

## OVERVIEW

YAML issue forms for human triage and Codex automation. This directory owns issue intake shape, default labels, and required context quality.

## STRUCTURE

```text
.github/ISSUE_TEMPLATE/
├── bug_report.yml        # Standard bug intake with severity and priority
├── feature_request.yml   # Feature and enhancement intake
├── service_request.yml   # New homelab service provisioning request
├── issue-form.yml        # General Korean issue form
├── codex-task.yml        # Execution-ready Codex task template
├── codex-ci-fix.yml      # CI failure handoff to Codex
├── codex-refactor.yml    # Behavior-preserving refactor request
└── config.yml            # Blank issues disabled + redirect links
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Bug intake | `bug_report.yml` | Reproduction steps, expected vs actual, severity, priority. |
| Feature intake | `feature_request.yml` | Kind, motivation, solution, acceptance criteria. |
| Service provisioning | `service_request.yml` | Container/VM ID, resource estimate, infra dependencies. |
| General Korean intake | `issue-form.yml` | Broad catch-all issue entry. |
| Codex execution tasks | `codex-task.yml`, `codex-ci-fix.yml`, `codex-refactor.yml` | Workspace, risk, constraints, verification. |
| Template chooser and redirects | `config.yml` | Security and governance links live here, not in forms. |

## CONVENTIONS

- Use YAML forms, not markdown issue templates.
- Apply top-level labels for immediate routing; forms should reduce follow-up triage work.
- Prefer required dropdowns for type, priority, risk, or workspace selection.
- Codex templates must be execution-ready: specific target, constraints, and verification steps.
- Keep security reporting in `config.yml` contact links rather than duplicating disclosure instructions inside issue bodies.

## ANTI-PATTERNS

- Do not add blank freeform templates without labels or validation.
- Do not reference retired workspaces, stale workflow names, or outdated risk tiers.
- Do not put secrets, tokens, or live credentials in defaults, examples, or placeholder text.
- Do not duplicate parent workflow rules here; this scope owns intake quality, not CI implementation.
