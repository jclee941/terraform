#!/usr/bin/env bash
# create-pr.sh — Automated PR creation for proxmox homelab
#
# Usage:
#   ./scripts/create-pr.sh <branch-name> <commit-message> [pr-title] [pr-body]
#   ./scripts/create-pr.sh --json <branch-name> <commit-message> [pr-title] [pr-body]
#   ./scripts/create-pr.sh --dry-run <branch-name> <commit-message>
#
# Options:
#   --json      Output result as JSON (for agent consumption)
#   --dry-run   Show what would be done without executing
#
# Called by opencode agent or manually.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Cleanup: return to original branch on unexpected exit
_ORIG_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
cleanup() {
  local exit_code=$?
  if [ $exit_code -ne 0 ] && [ -n "$_ORIG_BRANCH" ]; then
    git checkout "$_ORIG_BRANCH" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# --- Parse flags ---
JSON_OUTPUT=false
DRY_RUN=false
while [[ "${1:-}" == --* ]]; do
    case "$1" in
        --json) JSON_OUTPUT=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "ERROR: Unknown flag: $1" >&2; exit 1 ;;
    esac
done

# --- Args ---
BRANCH="${1:?Usage: create-pr.sh [--json] [--dry-run] <branch-name> <commit-message> [pr-title] [pr-body]}"
COMMIT_MSG="${2:?Missing commit message}"
PR_TITLE="${3:-$COMMIT_MSG}"
PR_BODY="${4:-Auto-generated PR from opencode session.}"

log() { $JSON_OUTPUT || echo "$@"; }
err() { echo "ERROR: $*" >&2; exit 1; }

# --- Validation ---
command -v gh &>/dev/null || err "gh CLI not found"
gh auth status &>/dev/null 2>&1 || err "gh not authenticated. Run 'gh auth login'"
command -v git &>/dev/null || err "git not found"

# Check for changes
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    err "No changes to commit"
fi

# --- Get base branch ---
BASE_BRANCH=$(git rev-parse --abbrev-ref HEAD)
CHANGED_FILES=$(git status --porcelain | wc -l)

# --- Dry run ---
if $DRY_RUN; then
    echo "=== DRY RUN ==="
    echo "Base branch : $BASE_BRANCH"
    echo "New branch  : $BRANCH"
    echo "Commit msg  : $COMMIT_MSG"
    echo "PR title    : $PR_TITLE"
    echo "Files       : $CHANGED_FILES changed"
    echo ""
    echo "Would execute:"
    echo "  1. git checkout -b $BRANCH"
    echo "  2. git add -A && git commit -m '$COMMIT_MSG'"
    echo "  3. git push -u origin $BRANCH"
    echo "  4. gh pr create --base $BASE_BRANCH --head $BRANCH"
    echo "  5. git checkout $BASE_BRANCH"
    exit 0
fi

log "Base branch: $BASE_BRANCH ($CHANGED_FILES files changed)"

# --- Create feature branch ---
log "Creating branch: $BRANCH"
if git show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
    err "Branch '$BRANCH' already exists locally. Use a different name."
fi
git checkout -b "$BRANCH"

# --- Stage & Commit ---
git add -A
STAGED_COUNT=$(git diff --cached --numstat | wc -l)
log "Staged $STAGED_COUNT files"
git commit -m "$COMMIT_MSG" --no-verify
log "Committed: $COMMIT_MSG"

# --- Push ---
log "Pushing to origin/$BRANCH..."
git push -u origin "$BRANCH" 2>/dev/null || {
    # Rollback: return to base branch on push failure
    git checkout "$BASE_BRANCH" 2>/dev/null
    err "Push failed. Returned to $BASE_BRANCH."
}

# --- Create PR ---
log "Creating PR..."
PR_URL=$(gh pr create \
    --base "$BASE_BRANCH" \
    --head "$BRANCH" \
    --title "$PR_TITLE" \
    --body "$PR_BODY") || {
    # Push succeeded but PR creation failed
    git checkout "$BASE_BRANCH" 2>/dev/null
    err "PR creation failed. Branch '$BRANCH' was pushed. Create PR manually: gh pr create --base $BASE_BRANCH --head $BRANCH"
}

# --- Return to base branch ---
git checkout "$BASE_BRANCH"

# --- Output ---
if $JSON_OUTPUT; then
    cat <<EOF
{"status":"success","pr_url":"$PR_URL","branch":"$BRANCH","base":"$BASE_BRANCH","title":"$PR_TITLE","files_changed":$STAGED_COUNT}
EOF
else
    echo ""
    echo "==============================="
    echo "PR created successfully!"
    echo "URL: $PR_URL"
    echo "Branch: $BRANCH -> $BASE_BRANCH"
    echo "Files: $STAGED_COUNT changed"
    echo "==============================="
fi
