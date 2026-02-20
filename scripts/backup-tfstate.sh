#!/usr/bin/env bash
set -euo pipefail

# Terraform State Encrypted Backup
# Creates an AES-256 encrypted backup of terraform.tfstate

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${REPO_ROOT}/100-pve/envs/prod"
BACKUP_DIR="${REPO_ROOT}/.backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/tfstate_${TIMESTAMP}.enc"

# Cleanup on failure
cleanup() {
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        echo "ERROR: Backup failed with exit code ${exit_code}" >&2
        [[ -f "${BACKUP_FILE}" ]] && rm -f "${BACKUP_FILE}"
    fi
}
trap cleanup EXIT

# Ensure backup directory exists
mkdir -p "${BACKUP_DIR}"

# Add .backups to .gitignore if not already present
if ! grep -qF '.backups/' "${REPO_ROOT}/.gitignore" 2>/dev/null; then
    echo '.backups/' >> "${REPO_ROOT}/.gitignore"
fi

# Validate state file exists
STATE_FILE="${TF_DIR}/terraform.tfstate"
if [[ ! -f "${STATE_FILE}" ]]; then
    echo "ERROR: State file not found at ${STATE_FILE}" >&2
    exit 1
fi

# Check for encryption passphrase
if [[ -z "${TF_BACKUP_PASSPHRASE:-}" ]]; then
    echo "ERROR: TF_BACKUP_PASSPHRASE environment variable is not set" >&2
    echo "  Set it via: export TF_BACKUP_PASSPHRASE='your-secure-passphrase'" >&2
    echo "  Or use 1Password: export TF_BACKUP_PASSPHRASE=\$(op read 'op://homelab/terraform/secrets/backup_passphrase')" >&2
    exit 1
fi

# Create encrypted backup
echo "Creating encrypted backup of terraform.tfstate..."
openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
    -in "${STATE_FILE}" \
    -out "${BACKUP_FILE}" \
    -pass "env:TF_BACKUP_PASSPHRASE"

# Verify backup was created
if [[ -f "${BACKUP_FILE}" ]]; then
    SIZE=$(stat -c%s "${BACKUP_FILE}" 2>/dev/null || stat -f%z "${BACKUP_FILE}" 2>/dev/null)
    echo "Backup created: ${BACKUP_FILE} (${SIZE} bytes)"
else
    echo "ERROR: Backup file was not created" >&2
    exit 1
fi

# Prune old backups (keep last 10)
BACKUP_COUNT=$(find "${BACKUP_DIR}" -name "tfstate_*.enc" -type f | wc -l)
if [[ ${BACKUP_COUNT} -gt 10 ]]; then
    echo "Pruning old backups (keeping last 10)..."
    find "${BACKUP_DIR}" -name "tfstate_*.enc" -type f -printf '%T@ %p\n' | \
        sort -n | head -n -10 | awk '{print $2}' | xargs rm -f
fi

echo "Backup complete."
