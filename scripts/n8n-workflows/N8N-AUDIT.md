# n8n Workflow Audit Report

**Generated:** 2026-03-12
**Source:** Runtime inventory via n8n MCP + repo file comparison

## Summary

| Metric | Count |
|--------|-------|
| Total runtime workflows | 10 |
| Matched to repo export | 2 |
| Runtime-only (no export) | 8 |
| Active | 9 |
| Inactive | 1 |

## Runtime ↔ Repo Mapping

| # | Runtime Name | Workflow ID | Active | Repo Export | Status |
|---|---|---|---|---|---|
| 1 | User Request Tracker | `L14fp6YIifvWFWRu` | ✅ | `request-tracker.json` | ✅ Matched |
| 2 | PR Notification Router | `fPYtTsPCq1PATzEy` | ✅ | `pr-notification.json` | ✅ Matched |
| 3 | Action Required Auto-Approve | `fNvmpcJu7QuyXols` | ✅ | — | ❌ Runtime-only |
| 4 | Auto-Approve Webhook | `gnBG8EVeBIHiKNo4` | ✅ | — | ❌ Runtime-only |
| 5 | PR Auto-Approve | `pjWElyzkH3rH8FOj` | ✅ | — | ❌ Runtime-only |
| 6 | Codex PR Maintenance | `nmFbliGq5k2lYzfP` | ❌ | — | ❌ Runtime-only (inactive) |
| 7 | Automation Health Notifier | `osIGywvKmB0UChu0` | ✅ | — | ❌ Runtime-only |
| 8 | YouTube Video Generation Runner | `qBxAIexFX6cDeuZU` | ✅ | — | ❌ Runtime-only |

## Runtime-Only Workflow Details

### 1. Action Required Auto-Approve (`fNvmpcJu7QuyXols`)

- **Trigger:** Schedule (every 30 minutes)
- **Purpose:** Scans 16 `qws941/*` repositories for GitHub Actions runs with `status=action_required` from trusted actors and auto-approves them.
- **Trusted actors:** `dependabot[bot]`, `chatgpt-codex-connector[bot]`, `openai-code-agent[bot]`, `codex[bot]`, `Codex`
- **Credential:** GitHub PAT (`XjkyWj7MVX42464P`)
- **Nodes:** 7 (Schedule → GitHub search → Filter → Approve loop)
- **Classification:** CI automation — core operational need

### 2. Auto-Approve Webhook (`gnBG8EVeBIHiKNo4`)

- **Trigger:** Webhook at `/webhook/github-auto-approve`
- **Purpose:** Event-driven companion to the schedule-based poller (#1). Processes `workflow_run` webhook events with `action_required` status from the same trusted actors.
- **Credential:** Same GitHub PAT as #1
- **Nodes:** 3 (Webhook → Filter → Approve)
- **Classification:** CI automation — companion to #1, same operational need

### 3. PR Auto-Approve (`pjWElyzkH3rH8FOj`)

- **Trigger:** Webhook at `/webhook/pr-auto-approve`
- **Purpose:** Processes PR events (opened, labeled, reopened, synchronize, ready_for_review). Auto-approves PR review and enables auto-merge (squash via GraphQL) for eligible PRs.
- **Eligibility:** Trusted actors (same list as #1) OR PRs with eligible labels (`auto-merge`, `codex`, `sync`). Must be non-draft, open, and unmerged.
- **Features:** 10-second TTL dedup via staticData. Calls sub-workflow "Codex PR Maintenance" (#4).
- **Credential:** GitHub PAT
- **Nodes:** 7
- **Versions:** 2,330 (most iterated workflow)
- **Classification:** PR automation — core operational need

### 4. Codex PR Maintenance (`nmFbliGq5k2lYzfP`) — INACTIVE

- **Trigger:** Execute Workflow trigger (called from PR Auto-Approve #3)
- **Purpose:** Sub-workflow for PR hygiene. Auto-closes empty PRs (0 file changes). Removes `auto-merge` label and posts warning comment on PRs exceeding 500 lines of change.
- **Nodes:** 10 (Trigger → Get PR files → Branch: empty check → Branch: size check → Close/Comment/Label actions)
- **Status:** Deactivated. Functionality may be superseded or was too aggressive for current use.
- **Classification:** PR hygiene — dormant, needs evaluation for reactivation or removal

### 5. Automation Health Notifier (`osIGywvKmB0UChu0`)

- **Trigger:** Webhook at `/webhook/automation-health`
- **Purpose:** Bridges GitHub issue events to Slack notifications. Processes issues with labels `type:ci` or `automation-health` and titles containing `[Automation Health]` or `[CI Health]`.
- **Events:** opened, reopened, closed
- **Slack channel:** `C0AGRJ1QHJ6`
- **Credential:** Slack Bot Token (`Oq6RplVhTJ3Rr96J`)
- **Nodes:** 3 (Webhook → Filter → Slack post)
- **Classification:** Monitoring/alerting — operational observability

### 6. YouTube Video Generation Runner (`qBxAIexFX6cDeuZU`)

- **Trigger:** Webhook at `/webhook/youtube-video-generation-runner`
- **Purpose:** Receives channel name (default: `horror`) and mode (default: `dry-run`). Posts request to video generation API at `http://192.168.50.108:8000/api/v1/run`.
- **Nodes:** 4 (Webhook → HTTP Request → Response)
- **Classification:** Content pipeline — not core infra automation, tangential to homelab ops

## Recommendations

### Export to repo (create JSON SSoT files)

| Workflow | Recommended Filename | Rationale |
|----------|---------------------|-----------|
| Action Required Auto-Approve | `action-required-auto-approve.json` | Core CI automation, should be tracked |
| Auto-Approve Webhook | `auto-approve-webhook.json` | Companion to above, same lifecycle |
| PR Auto-Approve | `pr-auto-approve.json` | Core PR automation, heavily iterated |
| Automation Health Notifier | `automation-health-notifier.json` | Operational alerting, should be tracked |

### Leave runtime-only (do not export)

| Workflow | Rationale |
|----------|-----------|
| Codex PR Maintenance | Inactive. Evaluate for reactivation or deletion before exporting. |
| YouTube Video Generation Runner | Not core infra automation. Separate content pipeline concern. |

## Action Items

1. **Export 4 active infra workflows** to `scripts/n8n-workflows/` as JSON files.
2. **Update `scripts/n8n-workflows/AGENTS.md`** to reflect new exports and audit reference.
3. **Evaluate Codex PR Maintenance** — decide whether to reactivate, fix, or permanently delete.
4. **Consider separating YouTube workflow** into a dedicated content-pipeline n8n workspace if it grows.
5. **Credential audit** — verify GitHub PAT (`XjkyWj7MVX42464P`) and Slack Bot Token (`Oq6RplVhTJ3Rr96J`) are current and scoped correctly.
