#!/bin/bash
# cleanup-logs.sh - Clean up old OpenCode log files
# Run by systemd timer daily

set -euo pipefail

LOG_DIR="${HOME}/.local/share/opencode/log"
RETENTION_DAYS="${OPENCODE_LOG_RETENTION_DAYS:-3}"
MAX_SIZE_MB="${OPENCODE_LOG_MAX_SIZE_MB:-500}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

if [[ ! -d "$LOG_DIR" ]]; then
    log "Log directory not found: $LOG_DIR"
    exit 0
fi

# Count before
BEFORE_COUNT=$(find "$LOG_DIR" -type f -name "*.log" | wc -l)
BEFORE_SIZE=$(du -sm "$LOG_DIR" 2>/dev/null | cut -f1 || echo 0)

log "Starting cleanup: ${BEFORE_COUNT} files, ${BEFORE_SIZE}MB"

# Delete old log files
find "$LOG_DIR" -type f -name "*.log" -mtime "+${RETENTION_DAYS}" -delete

# If still over size limit, delete oldest files
CURRENT_SIZE=$(du -sm "$LOG_DIR" 2>/dev/null | cut -f1 || echo 0)
while [[ $CURRENT_SIZE -gt $MAX_SIZE_MB ]]; do
    OLDEST=$(find "$LOG_DIR" -type f -name "*.log" -printf '%T+ %p\n' | sort | head -1 | cut -d' ' -f2-)
    if [[ -n "$OLDEST" ]]; then
        log "Removing (size limit): $OLDEST"
        rm -f "$OLDEST"
    else
        break
    fi
    CURRENT_SIZE=$(du -sm "$LOG_DIR" 2>/dev/null | cut -f1 || echo 0)
done

# Remove empty directories
find "$LOG_DIR" -type d -empty -delete 2>/dev/null || true

# Count after
AFTER_COUNT=$(find "$LOG_DIR" -type f -name "*.log" 2>/dev/null | wc -l)
AFTER_SIZE=$(du -sm "$LOG_DIR" 2>/dev/null | cut -f1 || echo 0)

log "Cleanup complete: ${AFTER_COUNT} files, ${AFTER_SIZE}MB"
log "Removed: $((BEFORE_COUNT - AFTER_COUNT)) files, freed $((BEFORE_SIZE - AFTER_SIZE))MB"
