#!/bin/bash
#
# migrate-labels.sh - Migrate from old labels to new labels in Terraform state
#
# This script:
#   1. Removes 88 old label resources from state (8 repos × 11 old labels)
#   2. Imports 416 new label resources (16 repos × 26 new labels)
#   3. Reports summary of removed/imported/skipped
#
# Usage:
#   ./migrate-labels.sh          # Run migration
#   ./migrate-labels.sh --dry-run # Echo commands without executing
#

set -euo pipefail

# Script directory (use dirname for portability)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Dry-run flag
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# Counters
removed_count=0
imported_count=0
skipped_count=0

# Arrays
old_repos=(blacklist hycu_fsds propose resume splunk terraform tmux youtube)
old_labels=(automated bug ci dependencies documentation enhancement infrastructure keep-open pinned security terraform)

new_repos=(terraform blacklist safetywallet opencode qws941 tmux aimo3-prize march-mania kaggle-playground arc-prize agents-league propose resume hycu_fsds youtube splunk)
new_labels=(type:bug type:feature type:docs type:refactor type:ci type:chore type:security type:test type:infra priority:critical priority:high priority:medium priority:low status:blocked status:in-progress status:needs-review status:wontfix status:duplicate size/xs size/s size/m size/l size/xl sync auto-merge codex)

# Function to run terraform import with graceful failure
run_import() {
    local resource_addr="$1"
    local import_id="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] terraform import '$resource_addr' '$import_id'"
        return 0
    fi

    if terraform import "$resource_addr" "$import_id" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

echo "=============================================="
echo "Terraform Labels State Migration"
echo "=============================================="
echo ""
echo "Working directory: $SCRIPT_DIR"
echo "Mode: $([[ "$DRY_RUN" == "true" ]] && echo "DRY-RUN" || echo "LIVE")"
echo ""

# ==========================================
# Step 1: Remove old labels from state
# ==========================================
echo "----------------------------------------------"
echo "Step 1: Removing 88 old label resources..."
echo "----------------------------------------------"

for repo in "${old_repos[@]}"; do
    for label in "${old_labels[@]}"; do
        resource_addr="github_issue_label.standard[\"$repo/$label\"]"

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY-RUN] terraform state rm '$resource_addr'"
            ((removed_count++)) || true
        else
            if terraform state rm "$resource_addr" 2>/dev/null; then
                ((removed_count++)) || true
                echo "Removed: $repo/$label"
            else
                echo "Not in state (skipping): $repo/$label"
            fi
        fi
    done
done

echo ""
echo "Removed from state: $removed_count old label resources"

# ==========================================
# Step 2: Import new labels
# ==========================================
echo ""
echo "----------------------------------------------"
echo "Step 2: Importing new label resources..."
echo "----------------------------------------------"

for repo in "${new_repos[@]}"; do
    for label in "${new_labels[@]}"; do
        resource_addr="github_issue_label.standard[\"$repo/$label\"]"
        import_id="$repo:$label"

        if run_import "$resource_addr" "$import_id"; then
            ((imported_count++)) || true
            echo "Imported: $repo/$label"
        else
            ((skipped_count++)) || true
            echo "Skipped (not on GitHub): $repo/$label"
        fi
    done
done

echo ""
echo "Imported: $imported_count new label resources"
echo "Skipped: $skipped_count (labels not found on GitHub)"

# ==========================================
# Summary
# ==========================================
echo ""
echo "=============================================="
echo "Migration Summary"
echo "=============================================="
echo "Old labels removed from state: $removed_count"
echo "New labels imported:          $imported_count"
echo "New labels skipped:           $skipped_count"
echo "Total attempted:              $((imported_count + skipped_count))"
echo ""
echo "Expected: 88 old labels, 416 new labels (16 repos × 26 labels)"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo ">>> This was a DRY-RUN. No changes were made. <<<"
else
    echo ">>> Migration complete. Run 'terraform plan' to verify. <<<"
fi
